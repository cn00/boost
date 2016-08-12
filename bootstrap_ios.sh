#!/bin/bash
# http://blog.csdn.net/hursing/article/details/45439087
# 请自行修改路径，cd到boost解压后的目录下
dir=`dirname $0`
#cd "$dir/../../third_party/boost_1_57_0"
# 如果库文件已存在，直接退出
if [ -e ./stage/lib/libboost_date_time.a ]; then
  echo "libraries exist. no need to build."
  exit 0
fi

# 以下代码参考 https://gist.github.com/rsobik/7513324 ，原文使用的boost版本比较旧，不能使用。

: ${COMPILER:="clang++"}
: ${IPHONE_SDKVERSION:=`xcodebuild -showsdks | grep iphoneos | egrep "[[:digit:]]+\.[[:digit:]]+" -o | tail -1`}
: ${XCODE_ROOT:=`xcode-select -print-path`}
: ${EXTRA_CPPFLAGS:="-DBOOST_AC_USE_PTHREADS -DBOOST_SP_USE_PTHREADS -stdlib=libc++"}

echo "IPHONE_SDKVERSION: $IPHONE_SDKVERSION"
echo "XCODE_ROOT:        $XCODE_ROOT"
echo "COMPILER:          $COMPILER"

echo "bootstrap"
# 此脚本如果是被Xcode调用的话，会因为xcode export的某些变量导致失败，所以加了env -i。直接在命令行运行此脚本可以把env -i 去掉
env -i bash ./bootstrap.sh

echo "write project-config.jam"
# 默认生存的project-config.jam是编译Mac版的，这里直接调换掉
rm project-config.jam
cat >> project-config.jam <<EOF
using darwin : ${IPHONE_SDKVERSION}~iphone
: $XCODE_ROOT/Toolchains/XcodeDefault.xctoolchain/usr/bin/$COMPILER -arch armv7 -arch arm64 $EXTRA_CPPFLAGS
: <striper> <root>$XCODE_ROOT/Platforms/iPhoneOS.platform/Developer
: <architecture>arm <target-os>iphone
;
using darwin : ${IPHONE_SDKVERSION}~iphonesim
: $XCODE_ROOT/Toolchains/XcodeDefault.xctoolchain/usr/bin/$COMPILER -arch i386 -arch x86_64 $EXTRA_CPPFLAGS
: <striper> <root>$XCODE_ROOT/Platforms/iPhoneSimulator.platform/Developer
: <architecture>ia64 <target-os>iphone
;
EOF
# 上面的代码里，两个using darwin分别是编译真机版和模拟器版的设置。每多一种CPU架构就要再加一个-arch xxx。

echo "build boost iphone dev"
# all type
./bjam -j4 --build-dir=stage/iphone --stagedir=stage/iphone --build-type=complete --layout=tagged --toolset=darwin architecture=arm target-os=iphone macosx-version=iphone-${IPHONE_SDKVERSION} define=_LITTLE_ENDIAN stage
# # muti thread
# ./bjam -j4 --build-dir=stage/iphone --stagedir=stage/iphone --build-type=complete --layout=tagged --toolset=darwin architecture=arm target-os=iphone macosx-version=iphone-${IPHONE_SDKVERSION} define=_LITTLE_ENDIAN threading=multi stage
# # all shared
# ./bjam -j4 --build-dir=stage/iphone --stagedir=stage/iphone --build-type=complete --layout=tagged --toolset=darwin architecture=arm target-os=iphone macosx-version=iphone-${IPHONE_SDKVERSION} define=_LITTLE_ENDIAN link=shared stage
# # all muti thread
# ./bjam -j4 --build-dir=stage/iphone --stagedir=stage/iphone --build-type=complete --layout=tagged --toolset=darwin architecture=arm target-os=iphone macosx-version=iphone-${IPHONE_SDKVERSION} define=_LITTLE_ENDIAN link=shared threading=multi stage

echo "build boost iphone sim"
./bjam -j4 --build-dir=stage/iphonesim --stagedir=stage/iphonesim --build-type=complete --layout=tagged --toolset=darwin-${IPHONE_SDKVERSION}~iphonesim architecture=ia64 target-os=iphone macosx-version=iphonesim-${IPHONE_SDKVERSION} stage
# ./bjam -j4 --build-dir=stage/iphonesim --stagedir=stage/iphonesim --build-type=complete --layout=tagged --toolset=darwin-${IPHONE_SDKVERSION}~iphonesim architecture=ia64 target-os=iphone macosx-version=iphonesim-${IPHONE_SDKVERSION} threading=multi stage
# ./bjam -j4 --build-dir=stage/iphonesim --stagedir=stage/iphonesim --build-type=complete --layout=tagged --toolset=darwin-${IPHONE_SDKVERSION}~iphonesim architecture=ia64 target-os=iphone macosx-version=iphonesim-${IPHONE_SDKVERSION} link=shared stage
# ./bjam -j4 --build-dir=stage/iphonesim --stagedir=stage/iphonesim --build-type=complete --layout=tagged --toolset=darwin-${IPHONE_SDKVERSION}~iphonesim architecture=ia64 target-os=iphone macosx-version=iphonesim-${IPHONE_SDKVERSION} link=shared threading=multi stage

echo "lipo"
# 把各架构下的库文件合一，以便在xcode里可以少设置些搜索路径。做得更彻底些是各个分库合成一个大库。不过除非是把静态库加入到代码仓库，否则是浪费时间了。要合成的大库话请参考https://gist.github.com/rsobik/7513324原文。
mkdir -p stage/lib
for f in stage/iphone/lib/*.a
do
	i=${f#stage\/iphone\/lib\/}
    echo "$i"
    lipo -create stage/iphone/lib/$i stage/iphonesim/lib/$i -output stage/lib/$i
done
# 库文件最终放在./stage/lib/下

echo "Completed successfully"