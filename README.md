# AutoClick

App auto click chạy trên menu bar macOS (SwiftUI, macOS 13+).

## Build & chạy

```sh
./scripts/build-app.sh
open build/AutoClick.app
```

Lần đầu chạy cần cấp quyền **Accessibility**: System Settings → Privacy & Security → Accessibility → bật AutoClick.

> App được ký ad-hoc nên **mỗi lần build lại** macOS sẽ coi là app mới. Nếu click không ăn sau khi rebuild, hãy xoá AutoClick khỏi danh sách Accessibility (nút −) rồi thêm lại.

## Tính năng

**Auto Click**: click trái / phải / double, theo con trỏ hoặc tại một điểm cố định. Chỉnh được khoảng cách (ms) và độ lệch ngẫu nhiên ±ms. Có thể đặt dừng sau N lần hoặc sau X giây.

**Ghi & Phát lại**: ghi lại các click (kèm vị trí và thời gian chờ) vào app khác, rồi phát lại với số lần lặp (0 = vô hạn) và tốc độ 0.25x–4x. Bản ghi được lưu lại giữa các lần mở app.

## Phím tắt

| Phím | Chức năng |
|---|---|
| ⌃⌥S | Bắt đầu / dừng auto click |
| ⌃⌥R | Bắt đầu / dừng ghi |
| ⌃⌥P | Phát / dừng phát lại |
| Esc | Dừng tất cả |
| Chuột lên góc trên-trái màn hình | Dừng tất cả |
