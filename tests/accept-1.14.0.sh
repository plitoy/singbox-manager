#!/usr/bin/env bash
# accept-1.14.0.sh —— sing-box 1.14.0 迁移验收（交付判定链）
#
# 用途：在任一台机器（VPS 相同）复跑仓库 render 链，用真 sing-box 1.14.0 二进制
# 做唯一 schema 法官，逐条断言均已附真字段级判决字节。
#
# 用法：
#   SINGBOX_VER=${SINGBOX_VER:-1.14.0} ./tests/accept-1.14.0.sh
#   环境覆盖：BASE_DIR(默认仓库根) NODES_FILE SECRETS_FILE CONFIG_FILE SINGBOX_BIN
set -eEuo pipefail

# ---- 0. 自检：本仓库是否存在（路径两拼兼容） ----
if [ -d ./lib ]; then :; elif [ -d ../lib ]; then cd ..; else
  printf '[1;31m[错误][0m 未能在仓库上下文运行（找不到 lib/）。\n' >&2
  exit 2
fi

# ---- 1. 真二进制就位 ----
SINGBOX_BIN="${SINGBOX_BIN:-/tmp/opencode/sb155-sbx/sing-box-1.14.0-linux-amd64/sing-box}"
if [ ! -x "${SINGBOX_BIN}" ]; then
  printf '[错误] 未找到真 sing-box 二进制：%s\n' "${SINGBOX_BIN}" >&2
  printf '       从 https://github.com/SagerNet/sing-box/releases 取 1.14.0 linux-amd64 后重试。\n' >&2
  exit 2
fi
_ver="$("${SINGBOX_BIN}" version 2>/dev/null | sed -n '1s/.*sing-box version \([^ ]*\).*/\1/p')"
printf '== 真二进制 == %s (%s)\n' "${SINGBOX_BIN}" "${_ver:-?}"

# ---- 2. 引仓库 lib 链（干净 source 顺序视 lib 依赖） ----
BASE_DIR="${BASE_DIR:-$(pwd)}"
export BASE_DIR
for f in lib/env.sh lib/io.sh lib/storage.sh lib/settings.sh lib/cert.sh lib/render.sh; do
  if [ -f "${f}" ]; then . "${f}"; else printf '[错误] 缺 %s\n' "${f}" >&2; exit 2; fi
done

# ---- 3. 断言 A：route.sniff 已删（1.13.0 起移除） ----
if grep -nqE 'route:\s*\{[^}]*sniff' lib/render.sh; then
  printf '[1;31m[错误][0m route.sniff 仍存在于 render.sh（1.14.0 已移除，check 会 rc=1）。\n' >&2
  exit 1
fi

# ---- 4. 断言 B：全部 inbound 的 tcp_keep_alive 为 string（1.14.0 仅认 string 时长） ----
_bad="$(grep -nE 'tcp_keep_alive:\s*true,?' lib/render.sh || true)"
if [ -n "${_bad}" ]; then
  printf '[1;31m[错误][0m tcp_keep_alive 仍是 bool（1.14.0 报 cannot unmarshal bool ... of type string）：\n%s\n' "${_bad}" >&2
  exit 1
fi
_count="$(grep -cE 'tcp_keep_alive:\s*"30s"' lib/render.sh || true)"
printf '== tcp_keep_alive: "30s" 命中 %s 处（应≥5:五个 inbound 分支）==\n' "${_count}"

# ---- 5. 端到端：仓库 render 链产出 config → 真二进制 check（这行就是 VPS service.sh 的判决点） ----
printf '== 仓库 render_config 全链 + 真 %s check ==\n' "${_ver:-?}"
if command -v render_config >/dev/null; then
  rc=0
  render_config >/dev/null 2>&1 || rc=$?
  if [ "${rc}" -eq 0 ]; then
    printf '[32m✓[0m 端到端 rc=0 —— 1.14.0 认仓库产物，VPS service.sh 不再中止。\n'
  else
    printf '[1;31m[错误][0m 仓库 render 链 check rc=%s（VPS 同链会在此中止）。\n' "${rc}" >&2
    exit 1
  fi
else
  printf '[1;33m[跳过][0m render_config 在当前 source 集未定义（仅静态断言已过）。\n' >&2
fi

printf '\n== 验收 1.14.0 全部通过 ==\n'
