#ifndef IMPORT_AS_MEMBER_H
#define IMPORT_AS_MEMBER_H

struct __attribute__((swift_name("Struct1"))) IAMStruct1 {
  double x, y, z;
};

extern double IAMStruct1GlobalVar
    __attribute__((swift_name("Struct1.globalVar")));

extern struct IAMStruct1 IAMStruct1CreateSimple(double value)
    __attribute__((swift_name("Struct1.init(value:)")));

extern struct IAMStruct1 IAMStruct1Invert(struct IAMStruct1 s)
    __attribute__((swift_name("Struct1.inverted(self:)")));

extern void IAMStruct1InvertInPlace(struct IAMStruct1 *s)
    __attribute__((swift_name("Struct1.invert(self:)")));

extern struct IAMStruct1 IAMStruct1Rotate(const struct IAMStruct1 *s,
                                          double radians)
    __attribute__((swift_name("Struct1.translate(self:radians:)")));

extern double IAMStruct1GetRadius(struct IAMStruct1 s)
    __attribute__((swift_name("getter:Struct1.radius(self:)")));

extern void IAMStruct1SetRadius(struct IAMStruct1 s, double radius)
    __attribute__((swift_name("setter:Struct1.radius(self:_:)")));

extern double IAMStruct1GetAltitude(struct IAMStruct1 s)
    __attribute__((swift_name("getter:Struct1.altitude(self:)")));

extern void IAMStruct1SetAltitude(struct IAMStruct1 *s, double altitude)
    __attribute__((swift_name("setter:Struct1.altitude(self:_:)")));

extern double IAMStruct1GetMagnitude(struct IAMStruct1 s)
    __attribute__((swift_name("getter:Struct1.magnitude(self:)")));

extern void IAMStruct1SelfComesLast(double x, struct IAMStruct1 s)
    __attribute__((swift_name("Struct1.selfComesLast(x:self:)")));
extern void IAMStruct1SelfComesThird(int a, float b, struct IAMStruct1 s, double x)
    __attribute__((swift_name("Struct1.selfComesThird(a:b:self:x:)")));

#endif // IMPORT_AS_MEMBER_H
