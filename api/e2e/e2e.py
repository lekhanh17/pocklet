"""Kiểm thử đầu-cuối Web API Pocklet: gọi từng endpoint trên API đang chạy.

Cách chạy (API chạy ở máy này, database trống hoặc đã --seed-demo):
    pip install requests pillow
    python e2e.py                      # mặc định http://127.0.0.1:5080
    BASE=http://localhost:5080 python e2e.py
"""
import base64, datetime as dt, io, json, os, sys, random, string
import requests
from PIL import Image

BASE = os.environ.get("BASE", "http://127.0.0.1:5080")
UPLOADS = os.environ.get("UPLOADS", os.path.join(os.path.dirname(os.path.abspath(__file__)), "..", "Pocklet.Api", "uploads"))
VN = dt.timezone(dt.timedelta(hours=7))
results = []


def check(name, cond, detail=""):
    results.append((name, bool(cond), detail))
    print(("PASS " if cond else "FAIL ") + name + ("" if cond else f"  -> {detail}"))
    return cond


def rnd(n=6):
    return "".join(random.choice(string.ascii_lowercase) for _ in range(n))


class Client:
    def __init__(self, token=None):
        self.token = token

    def h(self):
        return {"Authorization": f"Bearer {self.token}"} if self.token else {}

    def get(self, path, **kw):
        return requests.get(BASE + path, headers=self.h(), **kw)

    def post(self, path, json_=None, **kw):
        return requests.post(BASE + path, headers=self.h(), json=json_, **kw)

    def put(self, path, json_=None):
        return requests.put(BASE + path, headers=self.h(), json=json_)

    def patch(self, path, json_=None):
        return requests.patch(BASE + path, headers=self.h(), json=json_)

    def delete(self, path):
        return requests.delete(BASE + path, headers=self.h())


def jpeg_bytes(w=640, h=480, color=(200, 80, 40)):
    b = io.BytesIO()
    Image.new("RGB", (w, h), color).save(b, "JPEG", quality=80)
    return b.getvalue()


def png_bytes():
    b = io.BytesIO()
    Image.new("RGB", (50, 50), (1, 2, 3)).save(b, "PNG")
    return b.getvalue()


def register(email=None, pw="Matkhau123", name="Người thử"):
    email = email or f"{rnd()}@test.vn"
    r = requests.post(BASE + "/api/auth/register", json={"email": email, "password": pw, "displayName": name})
    return r, email


def vn_iso(y, m, d, hh=12, mm=0):
    return dt.datetime(y, m, d, hh, mm, tzinfo=VN).isoformat()


now_vn = dt.datetime.now(VN)
today = now_vn.date()
month_key = today.strftime("%Y-%m")

# ---------------- Auth (FR-01..04) ----------------
r, email1 = register(name="Anh Một")
check("register 200/201", r.status_code in (200, 201), r.text)
body = r.json()
c1 = Client(body["token"])
check("register returns user + token", body["user"]["email"] == email1 and body["token"], body)
claims = json.loads(base64.urlsafe_b64decode(body["token"].split(".")[1] + "==="))
days = (claims["exp"] - claims["iat"]) / 86400 if "iat" in claims else None
check("JWT expires after 7 days (BR-09)", days is not None and abs(days - 7) < 0.01, claims)
check("JWT has sub claim", "sub" in claims, claims)

r, _ = register(email=email1)
check("register duplicate email -> 409", r.status_code == 409, r.text)
check("409 carries field error for email", "email" in json.dumps(r.json()).lower(), r.text)
r, _ = register(pw="short")
check("register short password -> 400", r.status_code == 400, r.text)
r, _ = register(email="khong-hop-le")
check("register invalid email -> 400", r.status_code == 400, r.text)
r = requests.post(BASE + "/api/auth/register", json={"email": email1.upper(), "password": "Matkhau123", "displayName": "X"})
check("register duplicate email different case -> 409", r.status_code == 409, r.text)

r = requests.post(BASE + "/api/auth/login", json={"email": email1, "password": "sai-mat-khau"})
check("login wrong password -> 401", r.status_code == 401, r.text)
r = requests.post(BASE + "/api/auth/login", json={"email": email1.upper(), "password": "Matkhau123"})
check("login (email case-insensitive) -> 200", r.status_code == 200, r.text)

check("GET /me without token -> 401", requests.get(BASE + "/api/me").status_code == 401)
check("GET /me with garbage token -> 401", Client("abc.def.ghi").get("/api/me").status_code == 401)
r = c1.get("/api/me")
check("GET /me -> 200", r.status_code == 200 and r.json()["displayName"] == "Anh Một", r.text)
r = c1.put("/api/me", {"displayName": "Anh Một Sửa"})
check("PUT /me -> 200 and renamed", r.status_code == 200 and r.json()["displayName"] == "Anh Một Sửa", r.text)
r = c1.put("/api/me", {"displayName": ""})
check("PUT /me empty name -> 400", r.status_code == 400, r.text)
r = c1.put("/api/me/password", {"currentPassword": "sai", "newPassword": "MatKhauMoi1"})
check("change password wrong current -> 400 with field error", r.status_code == 400 and "currentpassword" in r.text.lower(), r.status_code)
r = c1.put("/api/me/password", {"currentPassword": "Matkhau123", "newPassword": "MatKhauMoi1"})
check("change password -> 204", r.status_code in (200, 204), r.text)
r = requests.post(BASE + "/api/auth/login", json={"email": email1, "password": "MatKhauMoi1"})
check("login with new password -> 200", r.status_code == 200, r.text)
check("login with old password -> 401", requests.post(BASE + "/api/auth/login", json={"email": email1, "password": "Matkhau123"}).status_code == 401)

r, email2 = register(name="Chị Hai")
c2 = Client(r.json()["token"])

# ---------------- Categories (FR-05, FR-06, BR-03) ----------------
r = c1.get("/api/categories")
cats = r.json()
check("8 default categories", r.status_code == 200 and len(cats) == 8 and all(c["isDefault"] for c in cats), cats)
names = [c["name"] for c in cats]
check("default names", names == ["Ăn uống", "Di chuyển", "Mua sắm", "Hoá đơn", "Giải trí", "Sức khoẻ", "Học tập", "Khác"], names)
khac = [c for c in cats if c["name"] == "Khác"][0]["id"]
an_uong = cats[0]["id"]
r = c1.post("/api/categories", {"name": "Cà phê", "icon": "local_cafe", "color": "#AA5500"})
check("create category -> 201", r.status_code in (200, 201), r.text)
cafe = r.json()["id"]
r = c1.post("/api/categories", {"name": "cà phê", "icon": "local_cafe", "color": "#AA5500"})
check("duplicate category name (case-insensitive) -> 400 field error", r.status_code == 400 and "name" in r.json().get("errors", {}), f"{r.status_code} {r.text}")
r = c1.post("/api/categories", {"name": "Ăn uống", "icon": "x", "color": "#AA5500"})
check("custom category cannot reuse a default name -> 400", r.status_code == 400, f"{r.status_code} {r.text}")
r = c1.post("/api/categories", {"name": "Màu sai", "icon": "x", "color": "red"})
check("bad colour -> 400", r.status_code == 400, r.text)
r = c1.put(f"/api/categories/{an_uong}", {"name": "Đổi", "icon": "x", "color": "#000000"})
check("edit default category -> 403", r.status_code == 403, r.text)
check("delete default category -> 403", c1.delete(f"/api/categories/{an_uong}").status_code == 403)
r = c1.put(f"/api/categories/{cafe}", {"name": "Cà phê sáng", "icon": "local_cafe", "color": "#AA5501"})
check("edit own category -> 200", r.status_code == 200 and r.json()["name"] == "Cà phê sáng", r.text)
check("other user edit -> 404", c2.put(f"/api/categories/{cafe}", {"name": "X", "icon": "x", "color": "#000000"}).status_code == 404)
check("other user delete -> 404", c2.delete(f"/api/categories/{cafe}").status_code == 404)
check("other user does not see it", all(c["id"] != cafe for c in c2.get("/api/categories").json()))
r = c2.post("/api/categories", {"name": "Cà phê sáng", "icon": "local_cafe", "color": "#AA5500"})
check("same name allowed for a different user", r.status_code in (200, 201), r.text)
r = c1.post("/api/categories", {"name": "Trà sữa", "icon": "x", "color": "#123456"})
tra = r.json()["id"]
r = c1.put(f"/api/categories/{tra}", {"name": "CÀ PHÊ SÁNG", "icon": "x", "color": "#123456"})
check("rename to another category's name -> 400", r.status_code == 400, r.text)
r = c1.put(f"/api/categories/{tra}", {"name": "  Trà sữa  ", "icon": "x", "color": "#123456"})
check("rename to own name (trimmed) -> 200", r.status_code == 200 and r.json()["name"] == "Trà sữa", r.text)
c1.delete(f"/api/categories/{tra}")
c2_cat = r.json()["id"]

# ---------------- Expenses (FR-07..09, BR-01, BR-02) ----------------
def new_exp(client, amount, cat, when, note=None):
    return client.post("/api/expenses", {"categoryId": cat, "amount": amount, "spentAt": when, "note": note})

t_noon = (now_vn - dt.timedelta(minutes=5)).isoformat()
r = new_exp(c1, 45000, an_uong, t_noon, "Phở bò Hà Nội")
check("create expense -> 201", r.status_code == 201, r.text)
e1 = r.json()
check("save response has id, amount, budgetAlerts", e1["amount"] == 45000 and e1["budgetAlerts"] == [] and e1["id"] > 0, e1)
check("spentAt round-trips", dt.datetime.fromisoformat(e1["spentAt"].replace("Z", "+00:00")) == dt.datetime.fromisoformat(t_noon), e1["spentAt"])
r = new_exp(c1, 0, an_uong, t_noon)
check("amount 0 -> 400", r.status_code == 400 and "amount" in r.text.lower(), r.text)
r = new_exp(c1, 1_000_000_001, an_uong, t_noon)
check("amount > 1 billion -> 400", r.status_code == 400, r.text)
r = new_exp(c1, 1_000_000_000, an_uong, t_noon)
check("amount exactly 1 billion -> 201", r.status_code == 201, r.text)
big_id = r.json()["id"]
check("delete big expense", c1.delete(f"/api/expenses/{big_id}").status_code == 204)
r = new_exp(c1, 1000, an_uong, (now_vn + dt.timedelta(hours=2)).isoformat())
check("future spentAt -> 400 (BR-02)", r.status_code == 400 and "spentat" in r.text.lower(), r.text)
r = new_exp(c1, 1000, 0, t_noon)
check("missing category -> 400", r.status_code == 400, r.text)
r = new_exp(c1, 1000, 99999, t_noon)
check("unknown category -> 400", r.status_code == 400, r.text)
r = new_exp(c1, 1000, c2_cat, t_noon)
check("other user's category -> 400", r.status_code == 400, r.text)
r = c1.post("/api/expenses", {"categoryId": an_uong, "amount": 1000})
check("missing spentAt -> 400", r.status_code == 400, r.text)
r = new_exp(c1, 1000, an_uong, t_noon, "x" * 201)
check("note > 200 chars -> 400", r.status_code == 400, r.text)
r = new_exp(c1, 1000, an_uong, t_noon, "   ")
check("blank note stored as null", r.status_code == 201 and r.json()["note"] is None, r.text)
c1.delete(f"/api/expenses/{r.json()['id']}")

check("GET own expense -> 200", c1.get(f"/api/expenses/{e1['id']}").status_code == 200)
check("GET other user's expense -> 404 (NFR-04)", c2.get(f"/api/expenses/{e1['id']}").status_code == 404)
check("PUT other user's expense -> 404", c2.put(f"/api/expenses/{e1['id']}", {"categoryId": c2_cat, "amount": 1, "spentAt": t_noon}).status_code == 404)
check("DELETE other user's expense -> 404", c2.delete(f"/api/expenses/{e1['id']}").status_code == 404)
r = c1.put(f"/api/expenses/{e1['id']}", {"categoryId": cafe, "amount": 50000, "spentAt": t_noon, "note": "Phở bò sửa"})
check("update expense -> 200", r.status_code == 200 and r.json()["amount"] == 50000 and r.json()["categoryId"] == cafe, r.text)
check("GET nonexistent expense -> 404", c1.get("/api/expenses/999999").status_code == 404)

# ---------------- Photos (FR-10..12, BR-05, BR-07, NFR-04) ----------------
def upload(client, exp_id, data, filename="a.jpg", ctype="image/jpeg", receipt=False):
    return requests.post(BASE + f"/api/expenses/{exp_id}/photos", headers=client.h(),
                         files={"file": (filename, data, ctype)}, data={"isReceipt": "true" if receipt else "false"})

jpg = jpeg_bytes()
r = upload(c1, e1["id"], jpg)
check("upload JPEG -> 201", r.status_code == 201, r.text)
p1 = r.json()["id"]
r = upload(c1, e1["id"], png_bytes(), "b.png", "image/png", receipt=True)
check("upload PNG as receipt -> 201", r.status_code == 201 and r.json()["isReceipt"] is True, r.text)
p2 = r.json()["id"]
r = upload(c1, e1["id"], b"hello this is not an image", "c.jpg", "image/jpeg")
check("non-image disguised as .jpg -> 415", r.status_code == 415, f"{r.status_code} {r.text}")
gif = b"GIF89a" + b"\x00" * 100
check("GIF -> 415", upload(c1, e1["id"], gif, "d.gif", "image/gif").status_code == 415)
big = b"\xff\xd8\xff\xe0" + os.urandom(2 * 1024 * 1024 + 10)
r = upload(c1, e1["id"], big)
check("> 2 MB -> 413", r.status_code == 413, f"{r.status_code} {r.text[:200]}")
r = requests.post(BASE + f"/api/expenses/{e1['id']}/photos", headers=c1.h(), files={"isReceipt": (None, "false")})
check("multipart without file -> 400", r.status_code == 400 and "file" in r.text.lower(), f"{r.status_code} {r.text}")
check("upload to other user's expense -> 404", upload(c2, e1["id"], jpg).status_code == 404)
for i in range(3):
    upload(c1, e1["id"], jpeg_bytes(color=(i * 40, 10, 10)))
r = upload(c1, e1["id"], jpg)
check("6th photo -> 409 (max 5)", r.status_code == 409, f"{r.status_code} {r.text}")

r = c1.get(f"/api/photos/{p1}")
check("GET photo -> 200 image/jpeg, same bytes", r.status_code == 200 and r.headers.get("content-type", "").startswith("image/jpeg") and r.content == jpg, r.headers)
check("GET photo without token -> 401", requests.get(BASE + f"/api/photos/{p1}").status_code == 401)
check("GET photo of other user -> 404", c2.get(f"/api/photos/{p1}").status_code == 404)
check("uploads folder not served publicly", requests.get(BASE + "/uploads/").status_code == 404)
r = c1.patch(f"/api/photos/{p1}", {"isReceipt": True})
check("PATCH isReceipt -> 200", r.status_code == 200 and r.json()["isReceipt"] is True, r.text)
check("PATCH other user's photo -> 404", c2.patch(f"/api/photos/{p1}", {"isReceipt": False}).status_code == 404)
detail = c1.get(f"/api/expenses/{e1['id']}").json()
check("expense lists 5 photos in upload order", [p["id"] for p in detail["photos"]][:2] == [p1, p2] and len(detail["photos"]) == 5, detail["photos"])
files_before = sum(len(f) for _, _, f in os.walk(UPLOADS))
r = c1.delete(f"/api/photos/{p2}")
check("DELETE photo -> 204", r.status_code == 204, r.text)
check("deleted photo -> 404 (FR-12)", c1.get(f"/api/photos/{p2}").status_code == 404)
files_after = sum(len(f) for _, _, f in os.walk(UPLOADS))
check("photo file removed from disk", files_after == files_before - 1, (files_before, files_after))
check("DELETE other user's photo -> 404", c2.delete(f"/api/photos/{p1}").status_code == 404)
names_on_disk = [f for _, _, fs in os.walk(UPLOADS) for f in fs]
check("server names files by GUID, not original name (BR-05)", all(len(n.split(".")[0]) == 32 or len(n.split(".")[0]) == 36 for n in names_on_disk) and "a.jpg" not in names_on_disk, names_on_disk[:3])

# ---------------- VN day boundary + calendar (FR-13..15, BR-02, BR-06) ----------------
# Use the previous month so every date is in the past.
first_this = today.replace(day=1)
pm_last = first_this - dt.timedelta(days=1)
pm = pm_last.replace(day=1)
pmk = pm.strftime("%Y-%m")
ea = new_exp(c1, 10000, an_uong, vn_iso(pm.year, pm.month, 10, 23, 30), "toi muon").json()   # 16:30 UTC on the 10th
eb = new_exp(c1, 20000, an_uong, vn_iso(pm.year, pm.month, 11, 0, 10), "sang som").json()    # 17:10 UTC on the 10th!
ec = new_exp(c1, 30000, an_uong, vn_iso(pm.year, pm.month, 11, 9, 0), "an trua").json()
ed = new_exp(c1, 40000, an_uong, vn_iso(pm.year, pm.month, 11, 20, 0), "khong anh").json()
pa = upload(c1, ec["id"], jpeg_bytes(color=(1, 1, 1))).json()["id"]
pb = upload(c1, ec["id"], jpeg_bytes(color=(2, 2, 2))).json()["id"]
pc = upload(c1, ea["id"], jpeg_bytes(color=(3, 3, 3))).json()["id"]
cal = c1.get(f"/api/calendar?month={pmk}").json()
days = {d["date"]: d for d in cal["days"]}
d10, d11 = f"{pmk}-10", f"{pmk}-11"
check("23:30 VN counts on the 10th", days.get(d10, {}).get("total") == 10000, days.get(d10))
check("00:10 VN counts on the 11th (not UTC day)", days.get(d11, {}).get("total") == 90000 and days[d11]["count"] == 3, days.get(d11))
check("BR-06 cover = first photo of latest expense WITH photos", days[d11]["coverPhotoId"] == pa, days[d11])
check("calendar month total", cal["total"] == 100000, cal["total"])
r = c1.get("/api/calendar?month=2026-13")
check("bad month -> 400", r.status_code == 400, r.text)
check("calendar of other user does not leak", c2.get(f"/api/calendar?month={pmk}").json()["total"] == 0)
r = c1.get(f"/api/expenses?from={d11}&to={d11}")
check("list from/to by VN day", r.json()["totalCount"] == 3 and r.json()["totalAmount"] == 90000, r.json())
check("list newest first", [x["id"] for x in r.json()["items"]] == [ed["id"], ec["id"], eb["id"]], [x["id"] for x in r.json()["items"]])

# ---------------- Search (FR-23) ----------------
r = c1.get("/api/expenses", params={"q": "trua"})
check("search by note", r.json()["totalCount"] == 1 and r.json()["items"][0]["id"] == ec["id"], r.json())
r = c1.get("/api/expenses", params={"min": 20000, "max": 30000, "from": pm.isoformat(), "to": pm_last.isoformat()})
check("amount range filter (numeric, not text)", sorted(x["amount"] for x in r.json()["items"]) == [20000, 30000], [x["amount"] for x in r.json()["items"]])
r = c1.get("/api/expenses", params={"min": 9000, "max": 10000})
check("min 9000 max 10000 -> only 10000 (text compare would fail)", [x["amount"] for x in r.json()["items"]] == [10000], [x["amount"] for x in r.json()["items"]])
r = c1.get("/api/expenses", params={"categoryId": cafe})
check("category filter", r.json()["totalCount"] == 1, r.json())
r = c1.get("/api/expenses", params={"pageSize": 2, "page": 1})
r2 = c1.get("/api/expenses", params={"pageSize": 2, "page": 2})
check("paging: totals equal, pages differ", r.json()["totalCount"] == r2.json()["totalCount"] and r.json()["items"][0]["id"] != r2.json()["items"][0]["id"], (r.json()["totalCount"], r2.json()["totalCount"]))
r = c1.get("/api/expenses", params={"from": d11, "to": d10})
check("from > to -> 400", r.status_code == 400, r.text)

# ---------------- Budgets (FR-16..18, BR-04) ----------------
mk = month_key
r = c1.put("/api/budgets", {"month": mk, "items": [{"categoryId": None, "limitAmount": 1_000_000}, {"categoryId": an_uong, "limitAmount": 100_000}]})
check("PUT budgets -> 200", r.status_code == 200, r.text)
b = r.json()
check("budget total + category", b["total"]["limitAmount"] == 1_000_000 and len(b["categories"]) == 1, b)
r = c1.put("/api/budgets", {"month": mk, "items": [{"categoryId": an_uong, "limitAmount": 1}, {"categoryId": an_uong, "limitAmount": 2}]})
check("two limits for same category -> 400 (FR-17)", r.status_code == 400, r.text)
r = c1.put("/api/budgets", {"month": mk, "items": [{"categoryId": c2_cat, "limitAmount": 1000}]})
check("budget for other user's category -> 400", r.status_code == 400, r.text)
r = c1.put("/api/budgets", {"month": "2026/11", "items": []})
check("bad month format -> 400", r.status_code == 400, r.text)

t = (now_vn - dt.timedelta(minutes=2)).isoformat()
r = new_exp(c1, 79_000, an_uong, t)
check("79% -> no alert", r.json()["budgetAlerts"] == [], r.json()["budgetAlerts"])
x79 = r.json()["id"]
r = new_exp(c1, 1_000, an_uong, t)
al = r.json()["budgetAlerts"]
check("reaching 80% -> one warning alert for Ăn uống", len(al) == 1 and al[0]["categoryId"] == an_uong and al[0]["level"] == "warning" and al[0]["percent"] == 80, al)
r = new_exp(c1, 5_000, an_uong, t)
check("still 85% -> no repeat alert", r.json()["budgetAlerts"] == [], r.json()["budgetAlerts"])
r = new_exp(c1, 15_000, an_uong, t)
al = r.json()["budgetAlerts"]
check("exactly 100% -> no exceeded yet (needs > 100%)", al == [], al)
r = new_exp(c1, 1, an_uong, t)
al = r.json()["budgetAlerts"]
check("> 100% -> exceeded alert", len(al) == 1 and al[0]["level"] == "exceeded", al)
r = new_exp(c1, 1000, an_uong, t)
check("no repeat exceeded alert", r.json()["budgetAlerts"] == [], r.json()["budgetAlerts"])
b = c1.get(f"/api/budgets?month={mk}").json()
cat_b = b["categories"][0]
check("budget label exceeded always shown", cat_b["level"] == "exceeded" and cat_b["spent"] == 101_001 and cat_b["percent"] == 101, cat_b)
# change limit resets warnings
c1.put("/api/budgets", {"month": mk, "items": [{"categoryId": None, "limitAmount": 1_000_000}, {"categoryId": an_uong, "limitAmount": 120_000}]})
r = new_exp(c1, 1, an_uong, t)
al = r.json()["budgetAlerts"]
check("after changing limit, warning fires again (84%)", len(al) == 1 and al[0]["level"] == "warning", al)
# update (edit) can also trigger alerts
r = c1.put(f"/api/expenses/{x79}", {"categoryId": an_uong, "amount": 100_000, "spentAt": t})
al = r.json()["budgetAlerts"]
check("editing an expense can trigger exceeded alert", any(a["level"] == "exceeded" and a["categoryId"] == an_uong for a in al), al)
# suggestion for next month
nm = (first_this + dt.timedelta(days=32)).replace(day=1).strftime("%Y-%m")
b = c1.get(f"/api/budgets?month={nm}").json()
sug = b.get("suggestedFromPreviousMonth")
check("next month suggests copying (FR-16)", b["total"] is None and sug and len(sug) == 2, b)
b = c1.get(f"/api/budgets?month={mk}").json()
check("current month has no suggestion", b.get("suggestedFromPreviousMonth") is None, b.get("suggestedFromPreviousMonth"))

# ---------------- Stats (FR-20, FR-21) ----------------
s = c1.get(f"/api/stats/monthly?month={mk}").json()
lst = c1.get("/api/expenses", params={"from": first_this.isoformat(), "to": today.isoformat(), "pageSize": 100}).json()
check("stats total equals list total", s["total"] == lst["totalAmount"], (s["total"], lst["totalAmount"]))
check("byCategory sums to total", sum(c["total"] for c in s["byCategory"]) == s["total"], s["byCategory"])
check("percent sums to ~100", abs(sum(c["percent"] for c in s["byCategory"]) - 100) < 0.5, [c["percent"] for c in s["byCategory"]])
import calendar as _cal
dim = _cal.monthrange(today.year, today.month)[1]
check("byDay has every day of month", len(s["byDay"]) == dim, len(s["byDay"]))
check("dailyBudget = limit / days in month", s["dailyBudget"] == 1_000_000 // dim or s["dailyBudget"] == round(1_000_000 / dim), s["dailyBudget"])
sp = c1.get(f"/api/stats/monthly?month={pmk}").json()
check("previous-month stats", sp["total"] == 100000 and sp["dailyBudget"] is None, sp)
day11 = [d for d in s["byDay"] if d["date"].endswith("-11")][0]
check("byDay.previousMonthTotal (day 11 last month = 90k)", day11["previousMonthTotal"] == 90000, day11)
check("changePercent present when previous month > 0", s["changePercent"] is not None, s["changePercent"])

# ---------------- Delete category moves expenses to Khác (BR-03) ----------------
c1.put("/api/budgets", {"month": mk, "items": [{"categoryId": cafe, "limitAmount": 50000}]})
r = c1.delete(f"/api/categories/{cafe}")
check("delete own category -> 204", r.status_code == 204, r.text)
check("its expense moved to Khác", c1.get(f"/api/expenses/{e1['id']}").json()["categoryId"] == khac)
b = c1.get(f"/api/budgets?month={mk}").json()
check("its budget deleted", all(x["categoryId"] != cafe for x in b["categories"]), b["categories"])

# ---------------- Delete expense removes photos (BR-07) ----------------
photo_ids = [p["id"] for p in c1.get(f"/api/expenses/{e1['id']}").json()["photos"]]
files_before = sum(len(f) for _, _, f in os.walk(UPLOADS))
check("DELETE expense -> 204", c1.delete(f"/api/expenses/{e1['id']}").status_code == 204)
check("deleted expense -> 404", c1.get(f"/api/expenses/{e1['id']}").status_code == 404)
check("its photos -> 404", all(c1.get(f"/api/photos/{pid}").status_code == 404 for pid in photo_ids))
files_after = sum(len(f) for _, _, f in os.walk(UPLOADS))
check("photo files removed from disk", files_before - files_after == len(photo_ids), (files_before, files_after, len(photo_ids)))

# ---------------- Demo account + Swagger ----------------
r = requests.post(BASE + "/api/auth/login", json={"email": "demo@pocklet.vn", "password": "Demo@1234"})
check("demo login", r.status_code == 200, r.text)
cd = Client(r.json()["token"])
dcal = cd.get(f"/api/calendar?month={mk}").json()
check("demo has data this month with photos", dcal["total"] > 0 and any(d["coverPhotoId"] for d in dcal["days"]), dcal["total"])
check("demo never has future expenses", all(d["date"] <= today.isoformat() for d in dcal["days"]), [d["date"] for d in dcal["days"]][-3:])
dprev = cd.get(f"/api/calendar?month={pmk}").json()
check("demo has last-month data", dprev["total"] > 0, dprev["total"])
db_ = cd.get(f"/api/budgets?month={mk}").json()
check("demo has budgets", db_["total"] is not None, db_)
first_cover = next(d["coverPhotoId"] for d in dcal["days"] if d["coverPhotoId"])
r = cd.get(f"/api/photos/{first_cover}")
check("demo photo downloadable", r.status_code == 200 and len(r.content) > 1000, r.status_code)
sw = requests.get(BASE + "/swagger/v1/swagger.json")
check("swagger.json -> 200", sw.status_code == 200 and "/api/expenses" in sw.text, sw.status_code)
check("swagger declares bearer security", "bearer" in sw.text.lower(), "")
check("swagger UI -> 200", requests.get(BASE + "/swagger/index.html").status_code == 200)
check("/ redirects to swagger", requests.get(BASE + "/", allow_redirects=False).status_code in (301, 302), "")

# ---------------- Error format ----------------
r = c1.get("/api/expenses/999999")
check("404 body is ProblemDetails (title, status)", "json" in r.headers.get("content-type", "") and r.json().get("status") == 404 and r.json().get("title"), r.text)
r = new_exp(c1, 0, an_uong, t_noon)
check("400 has errors map keyed by field", isinstance(r.json().get("errors"), dict), r.text)

fails = [n for n, ok, _ in results if not ok]
print(f"\n{len(results) - len(fails)} passed, {len(fails)} failed")
sys.exit(1 if fails else 0)
