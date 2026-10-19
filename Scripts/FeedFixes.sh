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

# 目标级热修：摘除 qualcommbe 的 kmod-qcom-ppe（2026-10-19）
#
# 背景：VIKINGYFY/immortalwrt@owrt 的 qualcommbe 目标把 kmod-qcom-ppe 放进
#   target/linux/qualcommbe/Makefile 的 DEFAULT_PACKAGES，该驱动与内核 6.18.x 的
#   dev_fill_forward_path 新签名不兼容（ppe_flowtable.c 编译失败），QCB-ALL 自 10-08 起中断。
#
# ⚠️ 关键实测：CONFIG_PACKAGE_kmod-qcom-ppe=n 写入 .config **无效**——
#   DEFAULT_PACKAGES 成员经 MODULE_DEFAULT_kmod-qcom-ppe=y 把 PACKAGE_ 符号的默认拉成 y，
#   make defconfig（conf --defconfig=.config Config.in）后实测仍解析为
#   CONFIG_PACKAGE_kmod-qcom-ppe=y。故必须从目标 Makefile 的 DEFAULT_PACKAGES 摘除。
#
# 作用面：仅在续行（以 \ 结尾的 DEFAULT_PACKAGES 续行）中移除该包名，不触碰文件其余内容；
#   同名字符串在本文件仅出现一次（DEFAULT_PACKAGES 块的续行）。
# 维护说明：上游修复 ppe_flowtable.c 的 dev_fill_forward_path 兼容后，删除本段恢复硬件加速。
#   禁用后为软件转发，功能不受影响。
drop_qcom_ppe() {
	local MK="./target/linux/qualcommbe/Makefile"
	[ -f "$MK" ] || return 0
	grep -q "kmod-qcom-ppe" "$MK" || return 0

	sed -i '/\\$/s/[[:space:]]*kmod-qcom-ppe[[:space:]]*/ /' "$MK"

	if grep -q "kmod-qcom-ppe" "$MK"; then
		echo "FeedFixes: WARNING kmod-qcom-ppe 摘除失败（Makefile 格式可能已变），请人工检查 $MK"
	else
		echo "FeedFixes: removed kmod-qcom-ppe from qualcommbe DEFAULT_PACKAGES (PPE驱动与6.18.x不兼容)"
	fi
}

fix_miniupnpd
drop_qcom_ppe
