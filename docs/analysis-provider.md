# Phân tích yêu cầu — vai Provider

- **Cặp đàm phán**: Core Business ↔ AI Vision / Access Gate
- **Product**: Smart Campus Operations Platform
- **Provider service**: Core Business Service (Dịch vụ Nghiệp vụ Trung tâm)
- **Consumer service**: AI Vision Service / Access Gate Service
- **Người viết**: Ngô Ngọc Bảo (ngocbao72)
- **Ngày**: 19/05/2026

---

## 1. Resource chính

| Resource | Mô tả | Thuộc tính bắt buộc | Thuộc tính tùy chọn |
|---|---|---|---|
| `Alert` | Cảnh báo vận hành Smart Campus khi có sự cố hoặc phát hiện bất thường (ví dụ: xâm nhập cổng chính, nhiệt độ vượt ngưỡng). | `id`, `sourceService`, `alertType`, `severity`, `message`, `status`, `createdAt`, `resolvedAt` | `relatedEventId` |
| `CampusEvent` | Sự kiện do cảm biến IoT hoặc lượt quẹt thẻ tại Access Gate gửi về để ghi nhận hành vi trên toàn campus. | `eventType`, `eventId`, `timestamp` | `deviceId`, `metric`, `value`, `unit` (cho SensorEvent); `gateId`, `cardId`, `decision` (cho AccessEvent) |

---

## 2. Action/API dự kiến

| Method | Path | Mục đích | Consumer gọi khi nào? |
|---|---|---|---|
| GET | `/health` | Kiểm tra trạng thái hoạt động của dịch vụ Core Business. | Consumer gọi định kỳ (polling) hoặc trong các luồng CI/CD, CD kiểm soát khả năng sống của dịch vụ. |
| POST | `/alerts` | Tạo cảnh báo vận hành mới vào hệ thống. | AI Vision hoặc Access Gate gọi khi phát hiện hành vi xâm nhập, người lạ xuất hiện, hoặc quẹt thẻ lỗi nghiêm trọng. |
| GET | `/alerts` | Lấy danh sách toàn bộ cảnh báo bằng cơ chế phân trang dựa trên cursor. | Consumer (như Dashboard Analytics hoặc Ban quản lý) cần duyệt qua lịch sử cảnh báo một cách tuần tự. |
| GET | `/alerts/recent` | Truy vấn các cảnh báo mới nhất đang mở hoặc nghiêm trọng. | Consumer cần cập nhật giao diện thông báo khẩn cấp hoặc gửi đẩy thông báo thời gian thực lên client. |
| GET | `/alerts/{alertId}` | Xem chi tiết thông tin và lịch sử giải quyết của một cảnh báo cụ thể. | Consumer gọi khi quản trị viên nhấp vào một cảnh báo cụ thể từ danh sách để xử lý nghiệp vụ. |
| POST | `/events` | Gửi sự kiện nghiệp vụ vào hệ thống (Sensor hoặc Access Gate). | Thiết bị IoT hoặc Cổng an ninh quẹt thẻ gửi dữ liệu đo đạc/ra vào thời gian thực về máy chủ. |

---

## 3. Error case

Tối thiểu 5 case.

| Status | Tình huống | Response body dự kiến |
|---:|---|---|
| 400 | Payload JSON bị sai định dạng, thiếu các thuộc tính bắt buộc, hoặc độ dài chuỗi không đạt chuẩn. | `Problem` (Problem Details chuẩn RFC 9457) chứa thông tin lỗi schema chi tiết cho từng field bị vi phạm. |
| 401 | Yêu cầu API thiếu header `Authorization` hoặc Bearer token hết hạn/không hợp lệ. | `Problem` thông báo chưa được xác thực nhằm ngăn chặn truy cập trái phép. |
| 403 | Token hợp lệ nhưng Consumer không có quyền (role) thực hiện thao tác (ví dụ: một cảm biến thường gọi GET `/alerts/recent`). | `Problem` thông báo Forbidden, chỉ ra thiếu quyền vận hành khẩn cấp. |
| 404 | Không tìm thấy Alert theo UUID cung cấp trên URL `/alerts/{alertId}`. | `Problem` trả về thông tin thực thể không tồn tại với chi tiết `alertId`. |
| 409 | Gửi sự kiện trùng lặp mã định danh `eventId` (vi phạm cơ chế Idempotency) hoặc tạo cảnh báo cho một sự kiện đã được giải quyết. | `Problem` trả về lỗi Conflict kèm theo mã lỗi trùng lặp chi tiết. |
| 422 | Dữ liệu đúng cấu trúc JSON nhưng vi phạm nghiệp vụ (ví dụ: `cardId` đúng regex nhưng thẻ này đã bị khóa từ trước). | `Problem` báo lỗi Unprocessable Entity, giữ chặt ràng buộc nghiệp vụ ở lớp application. |

---

## 4. Giả định bổ sung

Ghi rõ những điểm user story chưa nói nhưng Provider cần giả định.

- **Giả định 1**: Thời gian của hệ thống thống nhất dùng định dạng chuẩn ISO 8601 UTC (`YYYY-MM-DDTHH:mm:ssZ`).
- **Giả định 2**: Các định danh ID đều sử dụng chuẩn UUID v4 hoặc v7 để đảm bảo tính duy nhất toàn cục và tối ưu hóa sắp xếp theo thời gian (đối với UUID v7).
- **Giả định 3**: Tốc độ xử lý của Prism Mock Server cục bộ được mặc định là phản hồi lập tức để phục vụ kiểm thử nhanh, không phản ánh độ trễ thực tế của kết nối cơ sở dữ liệu.

---

## 5. Câu hỏi cho Consumer

1. Với endpoint `POST /alerts`, Consumer có cần hệ thống trả về toàn bộ thông tin chi tiết của Alert vừa tạo kèm theo `status` mặc định, hay chỉ cần mã định danh `id` và URI `Location` ở Header?
2. Khi Consumer gửi `SensorEvent`, trong trường hợp thiết bị IoT mất mạng lâu ngày và gửi dồn dập hàng nghìn sự kiện cũ, Consumer có cơ chế sắp xếp thứ tự gửi hoặc đính kèm `correlationId` để gom nhóm dữ liệu không?
3. Với `GET /alerts/recent`, Consumer kỳ vọng lấy tối đa bao nhiêu cảnh báo trong một lần gọi (mức trần limit tối đa được quy định là 100)?

---

## 6. Rủi ro tích hợp

| Rủi ro | Tác động | Đề xuất xử lý |
|---|---|---|
| Tên field không thống nhất | Consumer parse lỗi, hệ thống bị gián đoạn dữ liệu. | Chốt chặt naming convention (camelCase), kiểu dữ liệu và định dạng thông qua hợp đồng tĩnh `openapi.yaml`. |
| Payload sự kiện quá lớn | Gây nghẽn đường truyền, tốn bộ nhớ server, timeout kết nối. | Thống nhất content-type `application/json` và thiết lập giới hạn kích thước payload tối đa ở API Gateway. |
| Xung đột múi giờ | Dữ liệu log sự kiện bị lệch giờ, gây khó khăn lớn cho việc điều tra vết và phân tích dữ liệu. | Ràng buộc nghiêm ngặt định dạng date-time trong schema là `format: date-time` và tự động reject mọi chuỗi lệch chuẩn. |
