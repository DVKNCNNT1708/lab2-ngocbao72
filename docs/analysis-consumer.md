# Phân tích yêu cầu — vai Consumer

- **Cặp đàm phán**: Core Business ↔ AI Vision / Access Gate
- **Product**: Smart Campus Operations Platform
- **Consumer service**: AI Vision Service / Access Gate Service
- **Provider service**: Core Business Service (Dịch vụ Nghiệp vụ Trung tâm)
- **Người viết**: Ngô Ngọc Bảo (ngocbao72)
- **Ngày**: 19/05/2026

---

## 1. Resource Consumer cần nhận/gửi

| Resource | Consumer dùng để làm gì? | Field bắt buộc với Consumer | Field có thể tùy chọn |
|---|---|---|---|
| `Alert` | Consumer gửi yêu cầu tạo cảnh báo vận hành khẩn cấp lên Core Business khi hệ thống phân tích phát hiện đột nhập hoặc quẹt thẻ lỗi nghiêm trọng. Consumer cũng GET chi tiết Alert để hiển thị lịch sử xử lý. | `sourceService`, `alertType`, `severity`, `message` (khi gửi POST); `id`, `status`, `createdAt`, `resolvedAt` (khi nhận GET) | `relatedEventId`, `resolvedAt` (có thể null nếu cảnh báo chưa được xử lý xong) |
| `CampusEvent` | Consumer gửi sự kiện nghiệp vụ (SensorEvent từ IoT Ingestion, AccessEvent từ Access Gate) lên Core Business để lưu dấu vết, kích hoạt dòng công việc tiếp theo. | `eventType`, `eventId`, `timestamp` | `deviceId`, `metric`, `value`, `unit` (đối với SensorEvent); `gateId`, `cardId`, `decision` (đối với AccessEvent) |

---

## 2. API Consumer cần gọi

| Method | Path | Lúc nào gọi? | Kỳ vọng response |
|---|---|---|---|
| GET | `/health` | Khi khởi động Consumer hoặc định kỳ để kiểm tra mức độ sẵn sàng của Provider trước khi gửi dữ liệu quan trọng. | Trạng thái `status: ok`, tên dịch vụ trung tâm và thời gian chính xác của máy chủ. |
| POST | `/alerts` | Ngay lập tức khi AI Vision phát hiện người lạ, xâm nhập trái phép hoặc Access Gate ghi nhận thẻ giả/phá cổng. | Trạng thái `201 Created` kèm theo header `Location` chứa đường dẫn truy cập Alert vừa tạo và schema chi tiết của Alert. |
| GET | `/alerts` | Khi người dùng trên giao diện quản trị của Consumer (ví dụ: màn hình theo dõi cổng) cuộn xuống để xem thêm các bản ghi cảnh báo cũ hơn (Phân trang dựa trên cursor). | Danh sách các `items` cảnh báo dạng mảng, cờ báo `hasMore` và mã con trỏ `nextCursor` phục vụ việc truy vấn trang tiếp theo. |
| GET | `/alerts/recent` | Khi giao diện Dashboard của Consumer cần hiển thị danh sách các cảnh báo nóng nhất hiện tại. | Mảng `items` chứa các đối tượng Alert mới được tạo gần đây, sắp xếp giảm dần theo thời gian tạo. |
| GET | `/alerts/{alertId}` | Khi nhân viên bảo vệ nhấp vào chi tiết của một dòng thông báo cảnh báo trên màn hình ứng dụng của họ. | Toàn bộ thông tin trạng thái chi tiết của Alert, thời gian tạo, thời gian giải quyết nghiệp vụ cụ thể. |
| POST | `/events` | Khi thiết bị đọc RFID hoàn tất kiểm tra lượt thẻ, hoặc cảm biến IoT đọc được chỉ số môi trường định kỳ. | Trạng thái `201 Created` xác nhận hệ thống đã lưu nhận event thành công kèm theo thời điểm `acceptedAt`. |

---

## 3. Error case Consumer cần xử lý

Tối thiểu 5 case.

| Status | Consumer hiểu là gì? | Consumer sẽ xử lý thế nào? |
|---:|---|---|
| 400 | Request sai JSON schema (thiếu field, sai regex, sai kiểu). | Ghi nhận log lỗi mức độ Cảnh báo (Warning), ngừng gửi lại payload lỗi đó, hiển thị thông báo yêu cầu kiểm tra cấu hình phần mềm của Consumer. |
| 401 | Thiếu token hoặc token xác thực Bearer bị sai/hết hạn. | Kích hoạt luồng refresh token tự động, lưu tạm yêu cầu hiện tại vào hàng đợi trong bộ nhớ, sau đó gửi lại yêu cầu với token mới. |
| 403 | Không đủ quyền thực hiện thao tác gọi API này. | Ghi log hệ thống nghiêm trọng, hiển thị thông báo lỗi "Bạn không có quyền thực hiện chức năng này" và khóa tạm tính năng tương ứng trên giao diện UI. |
| 404 | Không tìm thấy mã `alertId` hoặc endpoint yêu cầu bị sai. | Hiển thị thông báo "Dữ liệu cảnh báo này không tồn tại hoặc đã bị xóa khỏi hệ thống", chuyển hướng người dùng về trang chủ quản trị. |
| 409 | Trùng lặp `eventId` (gửi trùng lặp do retry mạng) hoặc trạng thái thực thể bị xung đột. | Bỏ qua lỗi này nếu đó là hành động retry gửi trùng mã sự kiện (coi như thành công - Idempotency), hoặc hiển thị cảnh báo nghiệp vụ nếu là xung đột thật sự. |
| 422 | Dữ liệu đúng định dạng JSON nhưng vi phạm nghiệp vụ (thẻ RFID bị khóa, thiết bị IoT chưa được kích hoạt). | Đọc chi tiết danh sách `errors` trong đối tượng `Problem` nhận được từ server, hiển thị chi tiết lý do lỗi cụ thể cho người dùng (ví dụ: "Thẻ RFID này đã bị vô hiệu hóa bởi ban quản lý"). |

---

## 4. Giả định bổ sung

- **Giả định 1**: Provider đảm bảo tính sẵn sàng cao (Uptime > 99.9%) cho endpoint `/health` để Consumer có thể tin tưởng dùng làm cơ chế Circuit Breaker.
- **Giả định 2**: Cơ chế phân trang cursor của Provider đảm bảo tính nhất quán của dữ liệu khi có các bản ghi mới chèn vào giữa quá trình cuộn trang.
- **Giả định 3**: Chuẩn lỗi `Problem Details` (`application/problem+json`) được áp dụng đồng bộ trên tất cả các endpoint mà Provider cung cấp.

---

## 5. Câu hỏi cho Provider

1. Nếu gọi POST `/alerts` thành công, Provider có phát Webhook `alertCreated` cho chính Consumer (nếu Consumer đã đăng ký nhận Webhook) hay không? Việc này có gây lặp thông tin ở Consumer không?
2. Giới hạn tần suất gọi API (Rate Limit) áp dụng trên mỗi token của Consumer là bao nhiêu lượt/giây để Consumer thiết lập cơ chế Client-side Rate Limiting phù hợp?
3. Khi hệ thống Core Business bị lỗi cơ sở dữ liệu downstream (trả về mã 500), Provider có hỗ trợ lưu tạm sự kiện của Consumer vào hàng đợi trung chuyển không, hay Consumer phải tự thiết lập cơ chế retry/offline storage?

---

## 6. Rủi ro tích hợp

| Rủi ro | Tác động | Đề xuất xử lý |
|---|---|---|
| Provider đổi kiểu dữ liệu | Consumer parse lỗi runtime, gây crash ứng dụng hoặc hiển thị sai lệch thông tin cảnh báo nguy hiểm. | Chốt chặt type/format/pattern thông qua hợp đồng tĩnh `openapi.yaml`. Viết bài test tự động định kỳ đối chiếu schema (Contract Testing). |
| Provider thiếu mã lỗi chi tiết | Consumer khó xử lý lỗi tự động, dẫn tới chỉ có thể báo lỗi chung chung "Đã có lỗi xảy ra". | Chuẩn hóa toàn bộ cấu trúc lỗi theo Problem Details RFC 9457, đồng thời định nghĩa rõ enum các mã lỗi con (`code`) trong mảng `errors`. |
| Trễ mạng / API phản hồi chậm | Gây nghẽn luồng xử lý thời gian thực, dẫn tới việc mở cổng an ninh bị chậm, gây ùn tắc tại Access Gate. | Thống nhất thời gian timeout tối đa của API `/access/check` là 200ms. Nếu quá timeout, Consumer (Access Gate) sẽ tự động kích hoạt cơ chế Fail-Safe (ví dụ: Fail-Open hoặc Fail-Closed tùy theo cấu hình an ninh). |
