# Test 3: Curl từ pod khác để kiểm tra policy allow/deny

Thư mục này chỉ dành cho test số 3: vào một pod client trong cluster, chạy `curl` tới service đích, rồi kiểm tra `AuthorizationPolicy` hiện tại đang cho phép hay chặn kết nối.

Test này không tạo hoặc sửa retry policy, cũng không sửa `AuthorizationPolicy` trong Helm chart. Nó chỉ kiểm chứng hành vi của policy đã được deploy sẵn trong cluster.

## Mục tiêu kiểm thử

- Pod được phép: `curl-order`, dùng ServiceAccount `order`.
- Pod không được phép: `curl-unauthorized`, dùng ServiceAccount `default`.
- Service đích mặc định: `http://product/product/api/v1/products`.
- Kết quả mong đợi với pod được phép: HTTP `401`, nghĩa là Istio đã cho request đi qua và ứng dụng Spring Security yêu cầu token.
- Kết quả mong đợi với pod không được phép: HTTP `403`, nghĩa là Istio đã chặn request bằng RBAC.

## Chạy bằng PowerShell

Chạy từ thư mục `gitops-yas/curl-connectivity-test`:

```powershell
.\test-authz.ps1
```

Nếu muốn giữ lại pod sau khi test để debug:

```powershell
$env:KEEP_PODS = "true"
.\test-authz.ps1
```

## Chạy bằng Bash

Chạy từ thư mục `gitops-yas/curl-connectivity-test`:

```bash
bash test-authz.sh
```

Nếu muốn giữ lại pod sau khi test để debug:

```bash
KEEP_PODS=true bash test-authz.sh
```

## Tùy chỉnh service hoặc status mong đợi

Bash:

```bash
NAMESPACE=yas-dev \
SERVICE_URL=http://product/product/api/v1/products \
ALLOWED_EXPECTED_STATUS=401 \
DENIED_EXPECTED_STATUS=403 \
bash test-authz.sh
```

PowerShell:

```powershell
$env:NAMESPACE = "yas-dev"
$env:SERVICE_URL = "http://product/product/api/v1/products"
$env:ALLOWED_EXPECTED_STATUS = "401"
$env:DENIED_EXPECTED_STATUS = "403"
.\test-authz.ps1
```

## Script sẽ làm gì

1. Apply `curl-order-pod.yaml`.
2. Apply `curl-unauthorized-pod.yaml`.
3. Chờ cả hai pod chuyển sang trạng thái Ready.
4. Exec vào từng pod và curl tới `SERVICE_URL`.
5. So sánh HTTP status code với giá trị mong đợi.
6. In response headers/body để làm bằng chứng.
7. Xóa pod test sau khi chạy xong, trừ khi cấu hình `KEEP_PODS=true`.
