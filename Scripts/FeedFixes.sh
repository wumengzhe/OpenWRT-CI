#!/bin/bash
# SPDX-License-Identifier: MIT

# feed 热修：移除对当前上游版本已冗余或已失效的 feed 补丁
# 在 Custom Packages 步骤（feeds update/install 之后、make 之前）执行。
#
# 背景（2026-10-19）：immortalwrt/packages 将 miniupnpd bump 到 2.3.11 后，
# 以下三个补丁对 2.3.11 已不可用（曾导致 PonWRT-CI run#2 两个 job 构建中断）：
#   020-descr-filter-fix.patch —— 上游 miniupnp 2.3.11 已合并该「权限行解析器重写」
#                                 （tarball 内 upnppermissions.c 已含 iseol/get_sep/dot_cnt，
#                                  与 git tag miniupnpd_2_3_11 逐字节一致），quilt 应用必报
#                                  reversed/already-applied 而失败；
#   030-allow-private-fix.patch —— 上游已含修复形态（upnpsoap.c 为 if (GETFLAG(ALLOWPRIVATEIPV4MASK))）；
#   040-improve-logging.patch   —— 补丁过期（miniupnpd.c 12 个 hunk 挂 4 个，含 #ifdef 结构调整）。
# 保留并可干净应用的补丁：010-upnp-igdv2-compat、900-miniupnpd-format-xml（已本地实打验证 rc=0）。
#
# 维护说明：仅当 PKG_VERSION 仍为 2.3.11 时移除；feed 日后刷新/删除这些补丁后，
# 对应条目即可删除（文件不存在时 rm -f 自然无操作）。

fix_miniupnpd() {
	local PKG_DIR="./feeds/packages/net/miniupnpd"
	local MK="$PKG_DIR/Makefile"
	[ -f "$MK" ] || return 0

	local VER
	VER=$(grep -m1 '^PKG_VERSION:=' "$MK" | cut -d= -f2 | tr -d ' \r')
	if [ "$VER" != "2.3.11" ]; then
		echo "FeedFixes: miniupnpd PKG_VERSION=$VER (非2.3.11)，跳过热修"
		return 0
	fi

	local P
	for P in 020-descr-filter-fix.patch 030-allow-private-fix.patch 040-improve-logging.patch; do
		if [ -f "$PKG_DIR/patches/$P" ]; then
			rm -f "$PKG_DIR/patches/$P"
			echo "FeedFixes: removed redundant/broken miniupnpd patch: $P"
		fi
	done
}

fix_miniupnpd
