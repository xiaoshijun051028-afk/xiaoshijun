#!/usr/bin/env python3
# -*- coding: utf-8 -*-
"""
远程抽取 Godot 4.7-stable Windows 导出模板（windows_release_x86_64.exe）。
不下载整包(1.28GB)，只按 HTTP Range 取目标成员(~36MB 压缩)再 zlib 解压。
针对 release-assets CDN 仅支持起始式 Range（suffix range 返回 501）。
"""
import os, sys, time, struct, zlib, subprocess

URL = "https://github.com/godotengine/godot/releases/download/4.7-stable/Godot_v4.7-stable_export_templates.tpz"
PROJ = os.path.dirname(os.path.abspath(__file__))
APPDATA = os.environ.get("APPDATA", os.path.expanduser("~/AppData/Roaming"))
DEST_DIR = os.path.join(APPDATA, "Godot", "templates", "4.7.stable.official.5b4e0cb0f")
DEST = os.path.join(DEST_DIR, "windows_release_x86_64.exe")
TMP_COMP = os.path.join(PROJ, ".tmp_win_tpl_comp")   # 纯压缩数据（可续传）
_RNG = os.path.join(PROJ, ".tmp_rng.bin")
_CHK = os.path.join(PROJ, ".tmp_chunk.bin")
CHUNK = 4 * 1024 * 1024
TARGET = b"templates/windows_release_x86_64.exe"


def u16(b): return struct.unpack("<H", b)[0]
def u32(b): return struct.unpack("<I", b)[0]
def u64(b): return struct.unpack("<Q", b)[0]

def curl_range(start, end, out_path, max_time=300):
    rc = subprocess.run(
        ["curl", "-L", "--retry", "6", "--retry-delay", "4", "--max-time", str(max_time),
         "-r", "%d-%d" % (start, end), "-s", "-o", out_path, URL],
        capture_output=True).returncode
    return rc == 0 and os.path.exists(out_path) and os.path.getsize(out_path) > 0

def read_range(start, end):
    if not curl_range(start, end, _CHK):
        raise IOError("curl range %d-%d failed" % (start, end))
    with open(_CHK, "rb") as f:
        return f.read()

def get_total():
    for _ in range(10):
        out = subprocess.run(["curl", "-L", "--max-time", "60", "-r", "0-0", "-s", "-D", "-",
                              "-o", "/dev/null", URL], stdout=subprocess.PIPE).stdout.decode("utf-8", "ignore")
        for line in out.splitlines():
            if line.lower().startswith("content-range:"):
                return int(line.split("/")[-1].strip())
        print("  retry get_total..."); time.sleep(5)
    raise RuntimeError("no Content-Range after retries")


def locate():
    total = get_total()
    print("total =", total)
    eocd = None
    for back in (70000, 200000, 500000):
        s = max(0, total - back)
        eocd = read_range(s, total - 1)
        idx = eocd.rfind(b"PK\x05\x06")
        if idx >= 0:
            eocd = eocd[idx:]
            break
    if eocd is None:
        raise RuntimeError("EOCD not found")
    cd_off = u32(eocd[16:20]); cd_size = u32(eocd[12:16])
    print("cd_off=%d cd_size=%d" % (cd_off, cd_size))
    cd = read_range(cd_off, cd_off + cd_size - 1)
    P = cd.find(TARGET)
    if P < 0:
        raise RuntimeError("target not in CD")
    es = P - 46
    if cd[es:es+4] != b"PK\x01\x02":
        raise RuntimeError("entry sig mismatch at %d" % es)
    csize = u32(cd[es+20:es+24]); usize = u32(cd[es+24:es+28])
    nlen = u16(cd[es+28:es+30]); elen = u16(cd[es+30:es+32])
    hoff = u32(cd[es+42:es+46])
    extra = cd[P+nlen:P+nlen+elen]
    real_csize, real_usize, real_off = csize, usize, hoff
    if 0xFFFFFFFF in (csize, usize, hoff):
        ei = 0
        while ei + 4 <= len(extra):
            hid, hsz = u16(extra[ei:ei+2]), u16(extra[ei+2:ei+4])
            body = extra[ei+4:ei+4+hsz]
            if hid == 0x0001:
                p = 0
                if usize == 0xFFFFFFFF: real_usize = u64(body[p:p+8]); p += 8
                if csize == 0xFFFFFFFF: real_csize = u64(body[p:p+8]); p += 8
                if hoff == 0xFFFFFFFF:  real_off = u64(body[p:p+8]); p += 8
                break
            ei += 4 + hsz
    # read local header to confirm + get local nlen/elen
    lh = read_range(real_off, real_off + 63)
    if lh[:4] != b"PK\x03\x04":
        raise RuntimeError("local header sig mismatch: %r" % lh[:4])
    lnlen = u16(lh[26:28]); lelen = u16(lh[28:30])
    data_start = real_off + 30 + lnlen + lelen
    print("VERIFIED off=%d data_start=%d csize=%d usize=%d" % (real_off, data_start, real_csize, real_usize))
    return data_start, real_csize, real_usize


def fetch_chunked(start, end, out_path):
    have = os.path.getsize(out_path) if os.path.exists(out_path) else 0
    pos = start + have
    total = end - start + 1
    stall = 0
    while pos <= end:
        ce = min(pos + CHUNK - 1, end)
        ok = False
        for _ in range(4):
            if curl_range(pos, ce, _CHK):
                with open(_CHK, "rb") as f:
                    data = f.read()
                if data:
                    with open(out_path, "ab") as f:
                        f.write(data)
                    have += len(data); pos = ce + 1; stall = 0
                    print("  %d/%d (%.1f%%)" % (have, total, 100.0 * have / total), flush=True)
                    ok = True; break
            time.sleep(6)
        if not ok:
            stall += 1
            print("  stall at %d (have %d/%d)" % (pos, have, total), flush=True)
            if stall > 12:
                raise IOError("too many stalls at %d" % pos)
    return have


def main():
    data_start, csize, usize = locate()
    data_end = data_start + csize - 1
    print("fetching compressed member [%d-%d] (%d bytes, resumable)..." % (data_start, data_end, csize), flush=True)
    fetch_chunked(data_start, data_end, TMP_COMP)
    with open(TMP_COMP, "rb") as f:
        comp = f.read()
    print("decompressing %d -> %d ..." % (len(comp), usize), flush=True)
    out = zlib.decompress(comp, -15)
    if len(out) != usize:
        print("WARN size %d != expected %d" % (len(out), usize))
    os.makedirs(DEST_DIR, exist_ok=True)
    with open(DEST, "wb") as f:
        f.write(out)
    print("WROTE %s (%d bytes)" % (DEST, os.path.getsize(DEST)), flush=True)
    # cleanup temps
    for p in (TMP_COMP, _RNG, _CHK):
        try: os.remove(p)
        except OSError: pass
    print("DONE", flush=True)


if __name__ == "__main__":
    if len(sys.argv) > 1 and sys.argv[1] == "verify":
        locate()
    else:
        main()
