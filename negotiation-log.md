# Biên bản đàm phán hợp đồng API

- **Cặp đàm phán**: Core Business ↔ AI Vision / Access Gate
- **Product**: Smart Campus Operations Platform (Phân hệ Vận hành Cổng An ninh & Cảnh báo)
- **Provider**: Core Business Service (Đại diện: Ngô Ngọc Bảo - ngocbao72)
- **Consumer**: AI Vision / Access Gate Service (Đại diện: Nguyễn Minh Trí)
- **Phiên**: v1.0
- **Ngày**: 19/05/2026

---

## Issue #1: Định dạng trường thông tin mã thẻ RFID (`cardId`)

- **Raised by**: Provider (Core Business)
- **Endpoint**: `POST /events` (AccessEvent)
- **Concern**: Consumer muốn gửi `cardId` là chuỗi tự do (string không giới hạn). Provider lo ngại việc này dẫn tới rác dữ liệu trong DB và gây khó khăn khi đối chiếu với danh sách thẻ hợp lệ của lớp.
- **Proposal**: Áp dụng ràng buộc regex nghiêm ngặt cho `cardId` trong schema để chặn dữ liệu sai cấu trúc ngay từ cổng API Gateway.
- **Resolution**: Accepted. Thống nhất định dạng mã thẻ RFID bắt buộc phải có dạng `RFID-YYYY-NNN` (ví dụ: `RFID-2026-001`).
- **Rationale**: Đảm bảo toàn bộ thẻ quẹt trong campus tuân thủ một chuẩn duy nhất, giúp việc tối ưu hóa chỉ mục (indexing) trong Database và truy vấn lịch sử ra/vào nhanh gấp nhiều lần.
- **Impact**: Consumer (Access Gate) phải bổ sung validation ở thiết bị firmware hoặc biên dịch trước khi gửi payload lên server. Schema `AccessEvent` được thêm thuộc tính `pattern: '^RFID-[0-9]{4}-[0-9]{3}$'`.

---

## Issue #2: Cho phép thuộc tính `relatedEventId` có giá trị `null` thay vì bắt buộc

- **Raised by**: Consumer (AI Vision)
- **Endpoint**: `POST /alerts`
- **Concern**: Khi tạo cảnh báo (`POST /alerts`), Provider yêu cầu trường `relatedEventId` là bắt buộc và phải là UUID. Tuy nhiên, có những cảnh báo do vận hành viên tạo thủ công bằng tay từ dashboard điều hành, lúc đó hoàn toàn không có sự kiện tự động nào kích hoạt (không có `eventId`).
- **Proposal**: Cho phép `relatedEventId` chấp nhận giá trị `null` và khai báo kiểu dữ liệu kết hợp trong OpenAPI 3.1.
- **Resolution**: Accepted.
- **Rationale**: Đảm bảo tính linh hoạt của nghiệp vụ, hỗ trợ cả cảnh báo tự động từ AI/IoT lẫn cảnh báo thủ công từ con người. Đồng thời tuân thủ chuẩn OpenAPI 3.1: sử dụng union type `type: [string, "null"]` kết hợp `format: uuid` thay thế cho từ khóa `nullable: true` cũ của OpenAPI 3.0.
- **Impact**: Provider sửa lại Schema `CreateAlertRequest`, đưa trường `relatedEventId` ra khỏi danh sách `required` và định nghĩa kiểu dữ liệu là `type: [string, 'null']`.

---

## Issue #3: Cơ chế phân trang cho API lấy danh sách cảnh báo (`GET /alerts`)

- **Raised by**: Consumer (Dashboard UI)
- **Endpoint**: `GET /alerts`
- **Concern**: Ban đầu, Provider đề xuất cơ chế phân trang Offset-based (`limit` & `offset`). Consumer phản đối vì trong hệ thống giám sát Smart Campus, sự kiện cảnh báo được ghi nhận liên tục từng giây. Nếu dùng Offset-based, khi có cảnh báo mới chèn vào đầu bảng, người dùng cuộn xuống trang tiếp theo sẽ bị trùng lặp dữ liệu (bản ghi cuối trang trước bị đẩy sang đầu trang sau).
- **Proposal**: Chuyển sang cơ chế Cursor-based Pagination sử dụng một con trỏ mã hóa chuỗi (string cursor) đại diện cho bản ghi cuối cùng đã đọc.
- **Resolution**: Accepted.
- **Rationale**: Cursor-based Pagination đảm bảo tính nhất quán của dữ liệu (Data Consistency) khi cuộn trang thời gian thực, đồng thời cho hiệu năng truy vấn tối ưu ($O(1)$ thay vì $O(N)$ khi offset quá lớn).
- **Impact**: Schema phản hồi `AlertPage` được định nghĩa lại gồm: `items` (mảng alert), `nextCursor` (kiểu `[string, "null"]` để trỏ trang tiếp) và `hasMore` (boolean). Endpoint hỗ trợ parameter `cursor` ở dạng query.

---

## Issue #4: Định dạng chuẩn múi giờ và thời gian hiển thị

- **Raised by**: Consumer (AI Vision & Access Gate)
- **Endpoint**: Toàn bộ hệ thống API
- **Concern**: Consumer nhận thấy các thiết bị IoT và biên (Edge AI) chạy ở các múi giờ khác nhau (thiết bị thì UTC, thiết bị thì UTC+7). Nếu lưu thời gian không đồng bộ sẽ gây lệch pha log nghiêm trọng.
- **Proposal**: Áp dụng bắt buộc chuẩn ISO 8601 định dạng UTC (`YYYY-MM-DDTHH:mm:ssZ`) cho mọi thuộc tính thời gian (`timestamp`, `createdAt`, `resolvedAt`, `acceptedAt`).
- **Resolution**: Accepted.
- **Rationale**: UTC là chuẩn quốc tế tốt nhất cho hệ thống phân tán, loại bỏ hoàn toàn rủi ro sai lệch thời gian do chênh lệch múi giờ cục bộ hoặc quy ước giờ mùa hè (DST).
- **Impact**: Toàn bộ các trường thời gian trong `openapi.yaml` được cấu hình `type: string` và `format: date-time` kèm ví dụ kết thúc bằng ký tự `Z` (ví dụ: `2026-05-10T08:00:00Z`).

---

## Issue #5: Chuẩn hóa cấu trúc dữ liệu trả về khi xảy ra lỗi (Error Model)

- **Raised by**: Consumer (Access Gate)
- **Endpoint**: Toàn bộ API (Các mã lỗi 400, 401, 403, 404, 409, 422, 500)
- **Concern**: Mỗi lỗi hệ thống trả về một kiểu (chỗ thì chuỗi thuần túy, chỗ thì JSON lồng nhau khác cấu trúc), khiến mã nguồn xử lý ngoại lệ (Exception Handling) ở Consumer vô cùng phức tạp và dễ gây crash app.
- **Proposal**: Chuẩn hóa toàn bộ lỗi 4xx và 5xx theo chuẩn **RFC 9457 (Problem Details for HTTP APIs)**, sử dụng Content-Type là `application/problem+json`.
- **Resolution**: Accepted.
- **Rationale**: Chuẩn hóa này giúp client xây dựng một bộ xử lý lỗi dùng chung (Generic Error Handler) duy nhất. Cấu trúc `Problem` chứa mảng `errors` chi tiết gồm `field`, `code`, và `message` giúp client chỉ ra chính xác ô dữ liệu nào trên form bị lỗi.
- **Impact**: Định nghĩa schema `Problem` tập trung trong `components/schemas`. Sửa toàn bộ các response lỗi của API để tham chiếu `$ref` đến các response chuẩn như `BadRequest`, `Unauthorized`, `Forbidden`, `NotFound`, `Conflict`, `UnprocessableEntity`, `InternalServerError`.

---

## Issue #6: Cơ chế chống gửi lặp dữ liệu sự kiện (Idempotency)

- **Raised by**: Provider (Core Business)
- **Endpoint**: `POST /events`
- **Concern**: Trong môi trường mạng không ổn định của campus (Wi-Fi chập chờn), Access Gate hoặc IoT Ingestion gửi event lên server nhưng gặp timeout ở client. Client sẽ tự động gửi lại (retry). Nếu không kiểm soát, một lượt quẹt thẻ sẽ bị ghi nhận 2-3 lần trong DB, dẫn tới việc tính toán thống kê Analytics bị sai lệch hoàn toàn.
- **Proposal**: Consumer bắt buộc phải sinh một UUID duy nhất cho thuộc tính `eventId` của mỗi sự kiện ngay từ lúc khởi phát và gửi lên server. Server sẽ kiểm tra trùng lặp `eventId` này.
- **Resolution**: Accepted.
- **Rationale**: Đảm bảo tính Idempotency (độc lập tác động) cho luồng API ghi nhận sự kiện quan trọng mà không cần thiết lập cơ chế token phức tạp ở Header.
- **Impact**: Trường `eventId` thuộc schema `SensorEvent` và `AccessEvent` được chuyển vào mục `required` bắt buộc và có định dạng `format: uuid`. Khi phát hiện trùng lặp `eventId` trong DB, server sẽ từ chối xử lý và trả về mã lỗi `409 Conflict`.

---

# Chốt hợp đồng v1.0

- **Provider sign-off**: Ngô Ngọc Bảo (Core Business Lead)  
- **Consumer sign-off**: Nguyễn Minh Trí (Access Gate / AI Vision Lead)  
- **Witness (GV/TA)**: TS. Trần Văn A (Giảng viên phụ trách FIT4110)  
- **Date**: 19/05/2026

---

## Ghi chú warning nếu Spectral còn cảnh báo

| Warning | Lý do chấp nhận tạm thời | Kế hoạch sửa |
|---|---|---|
| Không có warning nào | Hợp đồng đã pass 100% Spectral lint sạch lỗi | Duy trì cấu trúc chuẩn |
