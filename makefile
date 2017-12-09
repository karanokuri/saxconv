########################################################
# Makefile for DMD
# Uses GNU Make-specific extensions
#


########################################################
# Build target
#

# ターゲットファイル (生成する exe ファイル)
TARGET = saxconv.exe

########################################################
# Command settings
#

# D Compiler
DC = dmd

# Remove command
RM = rm -f

# Resource Compiler
RCC = windres

########################################################
# dmd コンパイルオプションの設定
#

# 追加のインクルードパス
DFLAGS = -Isrc
DFLAGS += -version=DFL_UNICODE -Idfl

# リリース時のコンパイルオプション
RELEASE_DFLAGS += -O -release -inline

# デバッグ時のコンパイルオプション
DEBUG_DFLAGS += -g -d -debug -unittest -w
# DEBUG_DFLAGS += dfl_debug.lib -g -debug -unittest -w

# 標準でデバッグ時のコンパイルオプションを追加する
ifeq ($(BUILD_TYPE), release)
	DFLAGS += $(RELEASE_DFLAGS)
else
	DFLAGS += $(DEBUG_DFLAGS)
endif

########################################################
# リンカオプションの設定
#

# 追加のライブラリ
#
#   kernel32.lib と user32.lib, phobos.lib, snn.lib 以外は
#   自動でリンクされないので、ここで追加してください。
#
#LFLAGS = gdi32.lib
LFLAGS = lib\dfl.lib

# LFLAGS += -lib

# GUI アプリケーションをコンパイルする際のリンカオプション
#
#   真っ黒なコマンドプロンプトが出てきてイヤーンな人は、
#   以下のコメントを外してください。
#
ifeq ($(BUILD_TYPE), release)
	LFLAGS += -L/exet:nt/su:windows:4.0
endif

########################################################
# コンパイルするソースファイルのあるディレクトリ
#
#   ワイルドカード (*) も使えます。
#   この例では、カレントディレクトリにある、すべてのD言語
#   ソースファイルをコンパイルします。
#
INCLUDES = src

########################################################
# 除外するファイル
#
#   ワイルドカード (*) も使えます。
#   ここで指定されたファイルはコンパイルされません。
#   テスト用のソースファイルなどはここで指定してください。
#
EXCLUDES = ./test.d

########################################################
# ソースファイルの検索 / 除外
#
SRC := $(wildcard $(addsuffix /*.d, $(INCLUDES)))
SRC := $(filter-out $(wildcard $(EXCLUDES)), $(SRC))

OBJ := $(SRC:.d=.obj)

# *.map ファイル
MAP := $(TARGET:.exe=.map)

########################################################
# リソースファイルの検索 / 除外
#
RES := $(wildcard $(addsuffix /*.rc, $(INCLUDES)))
RES := $(filter-out $(wildcard $(EXCLUDES)), $(RES))
RES := $(RES:.rc=.res)

########################################################
# サフィックスルール
#

# *.d ファイルから *.obj ファイルを生成 (コンパイル)
.SUFFIXES: .d .obj .rc .res

.d.obj:
	$(DC) -c -of$@ $(DFLAGS) $<

.rc.res:
	$(RCC) -i $< -o $@

########################################################
# make ビルドルール
#

# all (default target)
.PHONY: all
all: $(TARGET)

.PHONY: debug release
debug: all
release:
	$(MAKE) rebuild "BUILD_TYPE=release"

# clean: 生成したすべてのターゲット (*.obj, *.map, *.exe) を削除
.PHONY: clean
clean:
	-$(RM) $(TARGET)
	-$(RM) $(MAP)
	-$(RM) $(OBJ)
	-$(RM) $(SRC:.d=.di)
	-$(RM) $(SRC:.d=.html)
	-$(RM) $(RES)

.PHONY: rebuild
rebuild: clean all

# ターゲットファイル: *.exe ファイルのビルド
$(TARGET): $(OBJ) $(RES)
	$(DC) -of$@ $(DFLAGS) $(LFLAGS) $^
