#!/usr/bin/env python3
"""tinh-ale.py - Tinh ALE truoc/sau lam cung va ROSI cho 5 moi de doa (Ha).

Chay:  python3 scripts/tinh-ale.py            in bang Markdown de dan vao docs/bao-cao.md
       python3 scripts/tinh-ale.py --json     in so lieu dang JSON

Diem tac dong/kha nang "truoc" (1-5) doc truc tiep tu docs/threat-model.json; diem "sau" la danh gia cua nhom, khai bao trong DE_DOA. Ba bang gia dinh
(SLE theo muc tac dong, ARO theo muc kha nang, don gia gio cong) la GIA DINH cua nhom,
khong phai so do duoc; doi o day thi bang trong bao cao doi theo.
"""
import json
import os
import sys

# --- Gia dinh 1: thiet hai cho mot su co (SLE, dong) theo muc tac dong 1-5 ---
SLE_THEO_TAC_DONG = {1: 2_000_000, 2: 10_000_000, 3: 40_000_000, 4: 120_000_000, 5: 300_000_000}
# --- Gia dinh 2: so su co moi nam (ARO) theo muc kha nang 1-5 ---
ARO_THEO_KHA_NANG = {1: 0.05, 2: 0.1, 3: 0.3, 4: 0.6, 5: 1.0}
# --- Gia dinh 3: don gia gio cong ky su, dong/gio; khau hao cong dung 3 nam ---
DON_GIA_GIO = 200_000
SO_NAM_KHAU_HAO = 3

# Moi de doa: (tac dong truoc, kha nang truoc, tac dong sau, kha nang sau,
#              gio dung ban dau, gio van hanh moi nam, trang thai bang chung)
DE_DOA = {
    "T1": ("Vượt quyền giữa phòng ban (RLS)",            5, 4, 5, 1, 12, 4, "Đã kiểm: T1-01..04, attack, defend"),
    "T2": ("Nghe lén tới nginx (TLS 1.2/1.3)",           5, 3, 5, 1,  8, 4, "Đã kiểm: testssl, test-nginx, attack"),
    "T3": ("Sửa gói tin app-DB (hostssl, ssl=on)",       4, 3, 4, 1,  8, 2, "Đã kiểm: T3-01..03, attack"),
    "T4": ("Lộ khóa mTLS (chỉ nhận diện, chưa có biện pháp)", 5, 2, 5, 2, 0, 0, "Không có ca kiểm; gitleaks chỉ là quét chung"),
    "T5": ("Chối bỏ thao tác DDL/đổi vai trò (pgaudit)", 3, 2, 2, 2,  8, 6, "Đã kiểm: T5-01..04, defend"),
}
# Diem tac dong/kha nang "truoc" duoc doc truc tiep tu docs/threat-model.json de khong lech so lieu;
# cac gia tri "sau" la danh gia cua nhom nen van khai bao trong DE_DOA.
def _doc_threat_model():
    duong_dan = os.path.join(os.path.dirname(os.path.abspath(__file__)), "..", "docs", "threat-model.json")
    with open(duong_dan, encoding="utf-8") as f:
        return {m["id"]: m for m in json.load(f)["moi_de_doa"]}


_TM = _doc_threat_model()
for _mid, _v in list(DE_DOA.items()):
    _ti, _ki = _TM[_mid]["tac_dong_1_5"], _TM[_mid]["kha_nang_xay_ra_1_5"]
    DE_DOA[_mid] = (_v[0], _ti, _ki) + _v[3:]

# Chi phi dung chung (CI/cong an toan, SBOM, ky Cosign, MANIFEST, gitleaks)
CHUNG_GIO_DUNG, CHUNG_GIO_VAN_HANH = 20, 10


def vn(chuoi):
    """Doi dinh dang so sang kieu Viet Nam: dau cham ngan cach hang nghin, dau phay thap phan."""
    return chuoi.replace(",", "\x00").replace(".", ",").replace("\x00", ".")


def vnd(x):
    return vn(f"{x / 1_000_000:,.1f}")


def tinh():
    ket_qua, tong = [], {"truoc": 0.0, "sau": 0.0, "chi_phi": 0.0}
    for mid, (ten, ti, ki, ts, ks, gd, gv, tt) in DE_DOA.items():
        truoc = SLE_THEO_TAC_DONG[ti] * ARO_THEO_KHA_NANG[ki]
        sau = SLE_THEO_TAC_DONG[ts] * ARO_THEO_KHA_NANG[ks]
        chi_phi = (gd / SO_NAM_KHAU_HAO + gv) * DON_GIA_GIO
        rosi = (truoc - sau - chi_phi) / chi_phi if chi_phi else None
        ket_qua.append(dict(id=mid, ten=ten, sle_truoc=SLE_THEO_TAC_DONG[ti], aro_truoc=ARO_THEO_KHA_NANG[ki],
                            ale_truoc=truoc, sle_sau=SLE_THEO_TAC_DONG[ts], aro_sau=ARO_THEO_KHA_NANG[ks],
                            ale_sau=sau, chi_phi=chi_phi, rosi=rosi, trang_thai=tt))
        tong["truoc"] += truoc
        tong["sau"] += sau
        tong["chi_phi"] += chi_phi
    chung = (CHUNG_GIO_DUNG / SO_NAM_KHAU_HAO + CHUNG_GIO_VAN_HANH) * DON_GIA_GIO
    tong["chi_phi"] += chung
    tong["chi_phi_chung"] = chung
    tong["rosi"] = (tong["truoc"] - tong["sau"] - tong["chi_phi"]) / tong["chi_phi"]
    return ket_qua, tong


def in_markdown(kq, tong):
    print("| Mối | Biện pháp | SLE trước | ARO trước | ALE trước | SLE sau | ARO sau | ALE sau | Chi phí/năm | ROSI | Bằng chứng |")
    print("|---|---|---|---|---|---|---|---|---|---|---|")
    for r in kq:
        print(f"| {r['id']} | {r['ten']} | {vnd(r['sle_truoc'])} | {vn(str(r['aro_truoc']))} | {vnd(r['ale_truoc'])} | "
              f"{vnd(r['sle_sau'])} | {vn(str(r['aro_sau']))} | {vnd(r['ale_sau'])} | {vnd(r['chi_phi'])} | "
              f"{('-' if r['rosi'] is None else vn(format(r['rosi'] * 100, ',.0f')) + '%')} | {r['trang_thai']} |")
    print(f"| Chung | CI, cổng an toàn, SBOM, Cosign, MANIFEST, gitleaks | - | - | - | - | - | - | {vnd(tong['chi_phi_chung'])} | - | - |")
    print(f"| **Tổng** | | | | **{vnd(tong['truoc'])}** | | | **{vnd(tong['sau'])}** | **{vnd(tong['chi_phi'])}** | **{vn(format(tong['rosi'] * 100, ',.0f'))}%** | |")
    print("\n(Đơn vị tiền: triệu đồng. SLE: thiệt hại một sự cố. ARO: số sự cố mỗi năm. ALE = SLE x ARO.)")


if __name__ == "__main__":
    kq, tong = tinh()
    if "--json" in sys.argv:
        print(json.dumps({"muc": kq, "tong": tong}, ensure_ascii=False, indent=2))
    else:
        in_markdown(kq, tong)
