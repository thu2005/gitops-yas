# Hướng Dẫn Kiểm Thử Cơ Chế Retry Tự Động (Retry Policy) trong Istio

Tài liệu này hướng dẫn cách chạy và kiểm tra tính năng Retry tự động (Retryable) khi service trả về lỗi 500 thông qua chính sách kết nối trong Service Mesh (Istio).

---

## 1. Các File Cấu Hình Sử Dụng
Các tệp cấu hình nằm trong thư mục `retry`:
1. **`product-retry.yaml`**: Định nghĩa chính sách Retry phía Client (3 lần thử, timeout 5s, khi gặp lỗi 5xx).
2. **`product-inbound-fault.yaml`**: EnvoyFilter dùng để inject lỗi HTTP 500 tại Inbound Proxy của Product Service.
3. **`curl-order-pod.yaml`**: Pod client dùng để gửi request test.

---

## 2. Các Bước Triển Khai Kiểm Thử

### Bước 1: Áp dụng các cấu hình lên Kubernetes
Hãy mở terminal tại thư mục `gitops-yas/retry` và chạy các lệnh sau:
```bash
# Áp dụng chính sách retry cho product service
kubectl apply -f product-retry.yaml

# Áp dụng bộ lọc lỗi EnvoyFilter cho product service
kubectl apply -f product-inbound-fault.yaml

# Triển khai Pod client kiểm thử
kubectl apply -f curl-order-pod.yaml
```

### Bước 2: Đợi Pod client sẵn sàng
Kiểm tra trạng thái Pod `curl-order`:
```bash
kubectl get pods -n yas-dev curl-order -w
```
*Đợi cho đến khi trạng thái báo `READY 2/2` và `STATUS Running`.*

### Bước 3: Gửi request kiểm thử qua curl
Chạy lệnh curl từ Pod client gọi đến Product Service:
```bash
kubectl exec -it curl-order -n yas-dev -- curl -v http://product/api/v1/products
```
* **Kết quả mong đợi:** Nhận về mã phản hồi `HTTP/1.1 500 Internal Server Error`.

---

## 3. Cách Lấy Bằng Chứng Kiểm Thử (Logs Evidence) cho Báo Cáo

### Bằng chứng 1: Log từ Client Proxy (Cờ lỗi URX)
Chạy lệnh lấy log của container proxy phía gửi:
```bash
kubectl logs curl-order -n yas-dev -c istio-proxy --tail=100
```
* **Minh chứng:** Tìm dòng log chứa `"GET /api/v1/products HTTP/1.1" 500 URX`. Cờ `URX` (Upstream Retry Limit Exceeded) xác nhận cuộc gọi đã tự động retry hết số lần quy định nhưng đều gặp lỗi.

### Bằng chứng 2: Log từ Server Proxy (4 request trùng Request ID)
Chạy lệnh lấy log của container proxy phía nhận (`product-service`):
```bash
kubectl logs -n yas-dev deployment/product -c istio-proxy --tail=50
```
* **Minh chứng:** Thấy **4 dòng log** yêu cầu `GET /api/v1/products` gửi tới `product-service` có cùng chung một mã **Request ID (Trace ID)** nhưng có mốc thời gian (timestamp) cách nhau rất ngắn. Điều này xác nhận cuộc gọi thực tế đã được tự động thử lại 3 lần.

---

## 4. Dọn Dẹp Tài Nguyên Sau Khi Kiểm Thử
Sau khi đã chụp ảnh và copy log làm báo cáo thành công, hãy xóa các tài nguyên test bằng lệnh:
```bash
kubectl delete -f product-inbound-fault.yaml
kubectl delete -f product-retry.yaml
kubectl delete -f curl-order-pod.yaml
```
