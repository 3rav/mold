#!/bin/bash
set -e
cd $(dirname $0)
echo -n "Testing $(basename -s .sh $0) ... "
t=$(pwd)/tmp/$(basename -s .sh $0)
mkdir -p $t

cat <<EOF | clang -c -o $t/a.o -xc -
void foo() {}
EOF

cat <<EOF | clang -c -o $t/b.o -xc -
void bar() {}
EOF

mkdir -p $t/foo/bar
rm -f $t/foo/bar/libfoo.a
ar rcs $t/foo/bar/libfoo.a $t/a.o $t/b.o

cat <<EOF | clang -c -o $t/c.o -xc -
void foo();
int main() {
  foo();
}
EOF

clang -fuse-ld=`pwd`/../mold -o $t/exe $t/c.o -Wl,--sysroot=$t/ \
  -Wl,-L=foo/bar -lfoo

clang -fuse-ld=`pwd`/../mold -o $t/exe $t/c.o -Wl,--sysroot=$t/ \
  -Wl,-L=/foo/bar -lfoo

clang -fuse-ld=`pwd`/../mold -o $t/exe $t/c.o -Wl,--sysroot=$t/ \
  '-Wl,-L$SYSROOTfoo/bar' -lfoo

clang -fuse-ld=`pwd`/../mold -o $t/exe $t/c.o -Wl,--sysroot=$t/ \
  '-Wl,-L$SYSROOT/foo/bar' -lfoo

! clang -fuse-ld=`pwd`/../mold -o $t/exe $t/c.o -lfoo >& /dev/null

! clang -fuse-ld=`pwd`/../mold -o $t/exe $t/c.o -Wl,--sysroot=$t \
  -Wl,-Lfoo/bar -lfoo >& /dev/null

echo OK
