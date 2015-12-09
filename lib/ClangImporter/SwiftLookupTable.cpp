//===--- SwiftLookupTable.cpp - Swift Lookup Table ------------------------===//
//
// This source file is part of the Swift.org open source project
//
// Copyright (c) 2014 - 2015 Apple Inc. and the Swift project authors
// Licensed under Apache License v2.0 with Runtime Library Exception
//
// See http://swift.org/LICENSE.txt for license information
// See http://swift.org/CONTRIBUTORS.txt for the list of Swift project authors
//
//===----------------------------------------------------------------------===//
//
// This file implements support for Swift name lookup tables stored in Clang
// modules.
//
//===----------------------------------------------------------------------===//
#include "SwiftLookupTable.h"
#include "swift/Basic/STLExtras.h"
#include "swift/Basic/Version.h"
#include "clang/AST/DeclObjC.h"
#include "clang/Serialization/ASTBitCodes.h"
#include "clang/Serialization/ASTReader.h"
#include "clang/Serialization/ASTWriter.h"
#include "llvm/ADT/SmallString.h"
#include "llvm/ADT/STLExtras.h"
#include "llvm/ADT/StringExtras.h"
#include "llvm/Bitcode/BitstreamReader.h"
#include "llvm/Bitcode/BitstreamWriter.h"
#include "llvm/Bitcode/RecordLayout.h"
#include "llvm/Support/OnDiskHashTable.h"

using namespace swift;
using namespace llvm::support;

/// Determine whether the new declarations matches an existing declaration.
static bool matchesExistingDecl(clang::Decl *decl, clang::Decl *existingDecl) {
  // If the canonical declarations are equivalent, we have a match.
  if (decl->getCanonicalDecl() == existingDecl->getCanonicalDecl()) {
    return true;
  }

  return false;
}

bool SwiftLookupTable::contextRequiresName(ContextKind kind) {
  switch (kind) {
  case ContextKind::ObjCClass:
  case ContextKind::ObjCProtocol:
  case ContextKind::Tag:
    return true;

  case ContextKind::TranslationUnit:
    return false;
  }
}

Optional<std::pair<SwiftLookupTable::ContextKind, StringRef>>
SwiftLookupTable::translateContext(clang::DeclContext *context) {
  // Translation unit context.
  if (context->isTranslationUnit())
    return std::make_pair(ContextKind::TranslationUnit, StringRef());

  // Tag declaration context.
  if (auto tag = dyn_cast<clang::TagDecl>(context)) {
    if (tag->getIdentifier())
      return std::make_pair(ContextKind::Tag, tag->getName());
    if (auto typedefDecl = tag->getTypedefNameForAnonDecl())
      return std::make_pair(ContextKind::Tag, typedefDecl->getName());
    return None;
  }

  // Objective-C class context.
  if (auto objcClass = dyn_cast<clang::ObjCInterfaceDecl>(context))
    return std::make_pair(ContextKind::ObjCClass, objcClass->getName());

  // Objective-C protocol context.
  if (auto objcProtocol = dyn_cast<clang::ObjCProtocolDecl>(context))
    return std::make_pair(ContextKind::ObjCProtocol, objcProtocol->getName());

  return None;
}

void SwiftLookupTable::addEntry(DeclName name, clang::NamedDecl *decl,
                                clang::DeclContext *effectiveContext) {
  assert(!Reader && "Cannot modify a lookup table stored on disk");

  // Translate the context.
  auto contextOpt = translateContext(effectiveContext);
  if (!contextOpt) return;
  auto context = *contextOpt;

  // Find the list of entries for this base name.
  auto &entries = LookupTable[name.getBaseName().str()];
  for (auto &entry : entries) {
    if (entry.Context == context) {
      // We have entries for this context.

      // Check whether this entry matches any existing entry.
      for (auto &existingEntry : entry.Decls) {
        if (matchesExistingDecl(decl, mapStoredDecl(existingEntry))) return;
      }

      // Add an entry to this context.
      entry.Decls.push_back(reinterpret_cast<uintptr_t>(decl));
      return;
    }
  }

  // This is a new context for this name. Add it.
  FullTableEntry newEntry;
  newEntry.Context = context;;
  newEntry.Decls.push_back(reinterpret_cast<uintptr_t>(decl));
  entries.push_back(newEntry);
}

SmallVector<clang::NamedDecl *, 4>
SwiftLookupTable::lookup(StringRef baseName,
                         clang::DeclContext *searchContext) {
  SmallVector<clang::NamedDecl *, 4> result;

  if (baseName.empty()) return result;

  // Find entries for this base name.
  auto known = LookupTable.find(baseName);

  // If we didn't find anything...
  if (known == LookupTable.end()) {
    // If there's no reader, we'll never find anything.
    if (!Reader) return result;

    // Add an entry to the table so we don't look again.
    known = LookupTable.insert({ baseName, { } }).first;
    if (!Reader->lookup(baseName, known->second)) return result;
  }

  // Translate context.
  Optional<std::pair<SwiftLookupTable::ContextKind, StringRef>> context;
  if (searchContext) {
    context = translateContext(searchContext);
    if (!context) return result;
  }

  // Walk each of the entries.
  for (auto &entry : known->second) {
    // If we're looking in a particular context and it doesn't match the
    // entry context, we're done.
    if (context && *context != entry.Context) continue;

    // Map each of the declarations.
    for (auto &storedDecl : entry.Decls) {
      result.push_back(mapStoredDecl(storedDecl));
    }
  }

  return result;
}

static void printName(clang::NamedDecl *named, llvm::raw_ostream &out) {
  // If there is a name, print it.
  if (!named->getDeclName().isEmpty()) {
    // If we have an Objective-C method, print the class name along
    // with '+'/'-'.
    if (auto objcMethod = dyn_cast<clang::ObjCMethodDecl>(named)) {
      out << (objcMethod->isInstanceMethod() ? '-' : '+') << '[';
      if (auto classDecl = objcMethod->getClassInterface()) {
        classDecl->printName(out);
        out << ' ';
      } else if (auto proto = dyn_cast<clang::ObjCProtocolDecl>(
                                objcMethod->getDeclContext())) {
        proto->printName(out);
        out << ' ';
      }
      named->printName(out);
      out << ']';
      return;
    }

    // If we have an Objective-C property, print the class name along
    // with the property name.
    if (auto objcProperty = dyn_cast<clang::ObjCPropertyDecl>(named)) {
      auto dc = objcProperty->getDeclContext();
      if (auto classDecl = dyn_cast<clang::ObjCInterfaceDecl>(dc)) {
        classDecl->printName(out);
        out << '.';
      } else if (auto categoryDecl = dyn_cast<clang::ObjCCategoryDecl>(dc)) {
        categoryDecl->getClassInterface()->printName(out);
        out << '.';
      } else if (auto proto = dyn_cast<clang::ObjCProtocolDecl>(dc)) {
        proto->printName(out);
        out << '.';
      }
      named->printName(out);
      return;
    }

    named->printName(out);
    return;
  }

  // If this is an anonymous tag declaration with a typedef name, use that.
  if (auto tag = dyn_cast<clang::TagDecl>(named)) {
    if (auto typedefName = tag->getTypedefNameForAnonDecl()) {
      printName(typedefName, out);
      return;
    }
  }
}

void SwiftLookupTable::deserializeAll() {
  if (!Reader) return;

  for (auto baseName : Reader->getBaseNames()) {
    (void)lookup(baseName, nullptr);
  }
}

void SwiftLookupTable::dump() const {
  // Dump the base name -> full table entry mappings.
  SmallVector<StringRef, 4> baseNames;
  for (const auto &entry : LookupTable) {
    baseNames.push_back(entry.first);
  }
  llvm::array_pod_sort(baseNames.begin(), baseNames.end());
  llvm::errs() << "Base name -> entry mappings:\n";
  for (auto baseName : baseNames) {
    llvm::errs() << "  " << baseName << ":\n";
    const auto &entries = LookupTable.find(baseName)->second;
    for (const auto &entry : entries) {
      llvm::errs() << "    ";
      switch (entry.Context.first) {
      case ContextKind::TranslationUnit:
        llvm::errs() << "TU";
        break;

      case ContextKind::Tag:
      case ContextKind::ObjCClass:
      case ContextKind::ObjCProtocol:
        llvm::errs() << entry.Context.second;
      }
      llvm::errs() << ": ";

      interleave(entry.Decls.begin(), entry.Decls.end(),
                 [](uint64_t entry) {
                   if ((entry & 0x01) == 0) {
                     auto decl = reinterpret_cast<clang::NamedDecl *>(entry);
                     printName(decl, llvm::errs());
                   } else {
                     llvm::errs() << "ID #" << (entry >> 1);
                   }
                 },
                 [] {
                   llvm::errs() << ", ";
                 });
      llvm::errs() << "\n";
    }
  }
}

// ---------------------------------------------------------------------------
// Serialization
// ---------------------------------------------------------------------------
using llvm::Fixnum;
using llvm::BCArray;
using llvm::BCBlob;
using llvm::BCFixed;
using llvm::BCGenericRecordLayout;
using llvm::BCRecordLayout;
using llvm::BCVBR;

namespace {
  enum RecordTypes {
    /// Record that contains the mapping from base names to entities with that
    /// name.
    BASE_NAME_TO_ENTITIES_RECORD_ID
      = clang::serialization::FIRST_EXTENSION_RECORD_ID,
  };

  using BaseNameToEntitiesTableRecordLayout
    = BCRecordLayout<BASE_NAME_TO_ENTITIES_RECORD_ID, BCVBR<16>, BCBlob>;

  /// Trait used to write the on-disk hash table for the base name -> entities
  /// mapping.
  class BaseNameToEntitiesTableWriterInfo {
    SwiftLookupTable &Table;
    clang::ASTWriter &Writer;

  public:
    using key_type = StringRef;
    using key_type_ref = key_type;
    using data_type = SmallVector<SwiftLookupTable::FullTableEntry, 2>;
    using data_type_ref = data_type &;
    using hash_value_type = uint32_t;
    using offset_type = unsigned;

    BaseNameToEntitiesTableWriterInfo(SwiftLookupTable &table,
                                      clang::ASTWriter &writer)
      : Table(table), Writer(writer)
    {
    }

    hash_value_type ComputeHash(key_type_ref key) {
      return llvm::HashString(key);
    }

    std::pair<unsigned, unsigned> EmitKeyDataLength(raw_ostream &out,
                                                    key_type_ref key,
                                                    data_type_ref data) {
      // The length of the key.
      uint32_t keyLength = key.size();

      // # of entries
      uint32_t dataLength = sizeof(uint16_t);

      // Storage per entry.
      for (const auto &entry : data) {
        // Context info.
        dataLength += 1;
        if (SwiftLookupTable::contextRequiresName(entry.Context.first)) {
          dataLength += sizeof(uint16_t) + entry.Context.second.size();
        }

        // # of entries.
        dataLength += sizeof(uint16_t);

        // Actual entries.
        dataLength += sizeof(clang::serialization::DeclID) * entry.Decls.size();
      }

      endian::Writer<little> writer(out);
      writer.write<uint16_t>(keyLength);
      writer.write<uint16_t>(dataLength);
      return { keyLength, dataLength };
    }

    void EmitKey(raw_ostream &out, key_type_ref key, unsigned len) {
      out << key;
    }

    void EmitData(raw_ostream &out, key_type_ref key, data_type_ref data,
                  unsigned len) {
      endian::Writer<little> writer(out);

      // # of entries
      writer.write<uint16_t>(data.size());

      for (auto &entry : data) {
        // Context.
        writer.write<uint8_t>(static_cast<uint8_t>(entry.Context.first));
        if (SwiftLookupTable::contextRequiresName(entry.Context.first)) {
          writer.write<uint16_t>(entry.Context.second.size());
          out << entry.Context.second;
        }

        // # of entries.
        writer.write<uint16_t>(entry.Decls.size());

        // Write the declarations.
        for (auto &declEntry : entry.Decls) {
          auto decl = Table.mapStoredDecl(declEntry);
          writer.write<clang::serialization::DeclID>(Writer.getDeclID(decl));
        }
      }
    }
  };
}

void SwiftLookupTableWriter::writeExtensionContents(
       clang::Sema &sema,
       llvm::BitstreamWriter &stream) {
  // Populate the lookup table.
  SwiftLookupTable table(nullptr);
  PopulateTable(sema, table);

  SmallVector<uint64_t, 64> ScratchRecord;

  // First, gather the sorted list of base names.
  SmallVector<StringRef, 2> baseNames;
  for (const auto &entry : table.LookupTable)
    baseNames.push_back(entry.first);
  llvm::array_pod_sort(baseNames.begin(), baseNames.end());

  // Form the mapping from base names to entities with their context.
  {
    llvm::SmallString<4096> hashTableBlob;
    uint32_t tableOffset;
    {
      llvm::OnDiskChainedHashTableGenerator<BaseNameToEntitiesTableWriterInfo>
        generator;
      BaseNameToEntitiesTableWriterInfo info(table, Writer);
      for (auto baseName : baseNames)
        generator.insert(baseName, table.LookupTable[baseName], info);

      llvm::raw_svector_ostream blobStream(hashTableBlob);
      // Make sure that no bucket is at offset 0
      endian::Writer<little>(blobStream).write<uint32_t>(0);
      tableOffset = generator.Emit(blobStream, info);
    }

    BaseNameToEntitiesTableRecordLayout layout(stream);
    layout.emit(ScratchRecord, tableOffset, hashTableBlob);
  }
}

namespace {
  /// Used to deserialize the on-disk base name -> entities table.
  class BaseNameToEntitiesTableReaderInfo {
  public:
    using internal_key_type = StringRef;
    using external_key_type = internal_key_type;
    using data_type = SmallVector<SwiftLookupTable::FullTableEntry, 2>;
    using hash_value_type = uint32_t;
    using offset_type = unsigned;

    internal_key_type GetInternalKey(external_key_type key) {
      return key;
    }

    external_key_type GetExternalKey(internal_key_type key) {
      return key;
    }

    hash_value_type ComputeHash(internal_key_type key) {
      return llvm::HashString(key);
    }

    static bool EqualKey(internal_key_type lhs, internal_key_type rhs) {
      return lhs == rhs;
    }

    static std::pair<unsigned, unsigned>
    ReadKeyDataLength(const uint8_t *&data) {
      unsigned keyLength = endian::readNext<uint16_t, little, unaligned>(data);
      unsigned dataLength = endian::readNext<uint16_t, little, unaligned>(data);
      return { keyLength, dataLength };
    }

    static internal_key_type ReadKey(const uint8_t *data, unsigned length) {
      return StringRef((const char *)data, length);
    }

    static data_type ReadData(internal_key_type key, const uint8_t *data,
                              unsigned length) {
      data_type result;

      // # of entries.
      unsigned numEntries = endian::readNext<uint16_t, little, unaligned>(data);
      result.reserve(numEntries);

      // Read all of the entries.
      while (numEntries--) {
        SwiftLookupTable::FullTableEntry entry;

        // Read the context.
        entry.Context.first =
          static_cast<SwiftLookupTable::ContextKind>(
            endian::readNext<uint8_t, little, unaligned>(data));
        if (SwiftLookupTable::contextRequiresName(entry.Context.first)) {
          uint16_t length = endian::readNext<uint16_t, little, unaligned>(data);
          entry.Context.second = StringRef((const char *)data, length);
          data += length;
        }

        // Read the declarations.
        unsigned numDecls = endian::readNext<uint16_t, little, unaligned>(data);
        while (numDecls--) {
          auto declID = endian::readNext<clang::serialization::DeclID, little,
                                         unaligned>(data);
          entry.Decls.push_back((declID << 1) | 0x01);
        }

        result.push_back(entry);
      }

      return result;
    }
  };

}

namespace swift {
  using SerializedBaseNameToEntitiesTable =
    llvm::OnDiskIterableChainedHashTable<BaseNameToEntitiesTableReaderInfo>;
}

clang::NamedDecl *SwiftLookupTable::mapStoredDecl(uint64_t &entry) {
  // If the low bit is unset, we have a pointer. Just cast.
  if ((entry & 0x01) == 0) {
    return reinterpret_cast<clang::NamedDecl *>(static_cast<uintptr_t>(entry));
  }

  // Otherwise, resolve the declaration.
  assert(Reader && "Cannot resolve the declaration without a reader");
  clang::serialization::DeclID declID = entry >> 1;
  auto decl = cast_or_null<clang::NamedDecl>(
                Reader->getASTReader().GetLocalDecl(Reader->getModuleFile(),
                                                    declID));

  // Update the entry now that we've resolved the declaration.
  entry = reinterpret_cast<uintptr_t>(decl);
  return decl;
}

SwiftLookupTableReader::~SwiftLookupTableReader() {
  OnRemove();
  delete static_cast<SerializedBaseNameToEntitiesTable *>(SerializedTable);
}

std::unique_ptr<SwiftLookupTableReader>
SwiftLookupTableReader::create(clang::ModuleFileExtension *extension,
                               clang::ASTReader &reader,
                               clang::serialization::ModuleFile &moduleFile,
                               std::function<void()> onRemove,
                               const llvm::BitstreamCursor &stream)
{
  // Look for the base name -> entities table record.
  SmallVector<uint64_t, 64> scratch;
  auto cursor = stream;
  auto next = cursor.advance();
  std::unique_ptr<SerializedBaseNameToEntitiesTable> serializedTable;
  while (next.Kind != llvm::BitstreamEntry::EndBlock) {
    if (next.Kind == llvm::BitstreamEntry::Error)
      return nullptr;

    if (next.Kind == llvm::BitstreamEntry::SubBlock) {
      // Unknown sub-block, possibly for use by a future version of the
      // API notes format.
      if (cursor.SkipBlock())
        return nullptr;
      
      next = cursor.advance();
      continue;
    }

    scratch.clear();
    StringRef blobData;
    unsigned kind = cursor.readRecord(next.ID, scratch, &blobData);
    switch (kind) {
    case BASE_NAME_TO_ENTITIES_RECORD_ID: {
      // Already saw base name -> entities table.
      if (serializedTable)
        return nullptr;

      uint32_t tableOffset;
      BaseNameToEntitiesTableRecordLayout::readRecord(scratch, tableOffset);
      auto base = reinterpret_cast<const uint8_t *>(blobData.data());

      serializedTable.reset(
        SerializedBaseNameToEntitiesTable::Create(base + tableOffset,
                                                  base + sizeof(uint32_t),
                                                  base));
      break;
    }

    default:
      // Unknown record, possibly for use by a future version of the
      // module format.
      break;
    }

    next = cursor.advance();
  }

  if (!serializedTable) return nullptr;

  // Create the reader.
  return std::unique_ptr<SwiftLookupTableReader>(
           new SwiftLookupTableReader(extension, reader, moduleFile, onRemove,
                                      serializedTable.release()));

}

SmallVector<StringRef, 4> SwiftLookupTableReader::getBaseNames() {
  auto table = static_cast<SerializedBaseNameToEntitiesTable*>(SerializedTable);
  SmallVector<StringRef, 4> results;
  for (auto key : table->keys()) {
    results.push_back(key);
  }
  return results;
}

/// Retrieve the set of entries associated with the given base name.
///
/// \returns true if we found anything, false otherwise.
bool SwiftLookupTableReader::lookup(
       StringRef baseName,
       SmallVectorImpl<SwiftLookupTable::FullTableEntry> &entries) {
  auto table = static_cast<SerializedBaseNameToEntitiesTable*>(SerializedTable);

  // Look for an entry with this base name.
  auto known = table->find(baseName);
  if (known == table->end()) return false;

  // Grab the results.
  entries = std::move(*known);
  return true;
}

