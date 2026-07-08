# Hướng Dẫn Kiểm Thử Chính Sách Ủy Quyền (Authorization Policy) trong Istio

Tài liệu này hướng dẫn cách kiểm tra chính sách bảo mật phân quyền kết nối (Service-to-Service Authorization) giữa các dịch vụ trong cụm YAS.

---

## 1. Cơ Chế Hoạt Động (Security Model)

Trong hệ thống, chúng ta đã triển khai chính sách `AuthorizationPolicy` tại [authorization-policy.yaml](file:///c:/D/DevOps/Project2/gitops-yas/helm/yas/templates/istio/authorization-policy.yaml):

* **Quy tắc ALLOW:** Chỉ các Pod sử dụng ServiceAccount được liệt kê (ví dụ: `order`, `storefront-bff`, `cart`,...) mới được phép kết nối đến `product` service.
* **Mặc định DENY:** Khi một dịch vụ có bất kỳ chính sách `ALLOW` nào, Istio tự động chặn (Deny-by-default) tất cả các nguồn không nằm trong danh sách trắng.

### Phân biệt 2 tầng bảo mật:

| Tầng | Công nghệ | Mã lỗi trả về |
|------|-----------|---------------|
| **Tầng 1 - Service Mesh** | Istio AuthorizationPolicy | `403 Forbidden` (RBAC: access denied) |
| **Tầng 2 - Ứng dụng** | Spring Security + Keycloak | `401 Unauthorized` (thiếu JWT Bearer Token) |

---

## 2. Các File Cấu Hình Sử Dụng

Các tệp nằm trong thư mục `setup-policy/`:
1. **`curl-order-pod.yaml`**: Pod client dùng ServiceAccount `order` — **HỢP LỆ**, được phép kết nối tới `product`.
2. **`curl-unauthorized-pod.yaml`**: Pod client dùng ServiceAccount `default` — **KHÔNG HỢP LỆ**, sẽ bị Istio chặn.

---

## 3. Các Bước Kiểm Thử (Test Plan)

### Bước 1: Khởi tạo các Pod kiểm thử
Hãy chạy các lệnh sau từ terminal tại thư mục `setup-policy/`:
```bash
# Triển khai Pod được cấp quyền (ServiceAccount: order)
kubectl apply -f curl-order-pod.yaml

# Triển khai Pod không được cấp quyền (ServiceAccount: default)
kubectl apply -f curl-unauthorized-pod.yaml
```
Kiểm tra trạng thái:
```bash
kubectl get pods -n yas-dev | grep curl
```
*(Đợi cho đến khi cả 2 Pod báo `READY 2/2` và `STATUS Running`)*

---

### Bước 2: Test trường hợp ĐƯỢC PHÉP truy cập (Authorized ✅)
Chạy lệnh curl từ Pod `curl-order`:
```bash
kubectl exec -it curl-order -n yas-dev -- curl -I http://product/product/api/v1/products
```

**Kết quả thu được:**
```
HTTP/1.1 401 Unauthorized
www-authenticate: Bearer resource_metadata="..."
x-envoy-upstream-service-time: 5
server: envoy
```

**Giải thích:** Mã `401` xác nhận rằng:
- ✅ Istio AuthorizationPolicy **ĐÃ CHO PHÉP** `curl-order` kết nối.
- ✅ Request **đã chạm tới ứng dụng Spring Boot** thật sự (có `x-envoy-upstream-service-time`).
- ℹ️ `401` là Spring Security yêu cầu Bearer Token — đây là tầng bảo mật của **ứng dụng**, không liên quan đến Istio.

---

### Bước 3: Test trường hợp BỊ CHẶN truy cập (Unauthorized ❌)
Chạy lệnh curl từ Pod `curl-unauthorized` (ServiceAccount `default` — KHÔNG có trong danh sách trắng):
```bash
kubectl exec -it curl-unauthorized -n yas-dev -- curl -I http://product/product/api/v1/products
```

**Kết quả thu được:**
```
HTTP/1.1 403 Forbidden
content-length: 19
content-type: text/plain
server: envoy
```

**Giải thích:** Mã `403` xác nhận rằng:
- ❌ Istio AuthorizationPolicy **ĐÃ CHẶN** `curl-unauthorized`.
- Body response là `RBAC: access denied` (19 ký tự).
- Request **KHÔNG chạm được vào ứng dụng** Spring Boot (không có header `x-content-type-options`, `x-xss-protection` của Spring).

---

## 4. Tóm Tắt Kết Quả Kiểm Thử

| Pod | ServiceAccount | Mã phản hồi | Nguồn chặn | Kết quả |
|-----|---------------|-------------|------------|---------|
| `curl-order` | `order` (hợp lệ) | `401 Unauthorized` | Spring Boot | ✅ Istio cho qua |
| `curl-unauthorized` | `default` (không hợp lệ) | `403 Forbidden` | **Istio Proxy** | ❌ Istio chặn |

Sự khác biệt giữa `401` và `403` chứng minh rõ ràng Istio **AuthorizationPolicy** đang hoạt động đúng và bảo vệ `product` service khỏi các nguồn truy cập không được ủy quyền.

---

## 5. Dọn Dẹp Tài Nguyên Sau Khi Kiểm Thử
Chạy lệnh sau để xóa các Pod test:
```bash
kubectl delete -f curl-order-pod.yaml
kubectl delete -f curl-unauthorized-pod.yaml
```
