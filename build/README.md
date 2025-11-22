# zRAM/SWAP Manager

[![Pipeline Status](https://gitlab.com/disa12311/zram-manager/badges/main/pipeline.svg)](https://gitlab.com/disa12311/zram-manager/-/pipelines)
[![License](https://img.shields.io/badge/license-GPL--3.0-blue.svg)](LICENSE)
[![Magisk](https://img.shields.io/badge/Magisk-15.3%2B-00B39B.svg)](https://github.com/topjohnwu/Magisk)
[![Android](https://img.shields.io/badge/Android-5.0%2B-3DDC84.svg)](https://www.android.com/)

Magisk module để quản lý zRAM/SWAP trên Android, tăng hiệu suất bằng cách nén RAM thay vì sử dụng disk paging.

## 📱 About zRAM

zRAM là module của Linux/Android kernel giúp tăng hiệu suất bằng cách:
- ✅ Tránh disk paging (chậm)
- ✅ Sử dụng compressed block device trong RAM (nhanh)
- ✅ Giữ nhiều app chạy background hơn
- ✅ Cải thiện multitasking

**Lưu ý:** zRAM KHÔNG làm chậm thiết bị hay ảnh hưởng pin. Nó sử dụng thuật toán nén/giải nén cực nhanh (LZ4/ZSTD).

## ⚡ Tính năng

- 🚀 **Tự động cấu hình** - Tính toán kích thước zRAM tối ưu dựa trên RAM
- 🎛️ **Volume Key Selector** - Chọn enable/disable khi cài đặt
- ⚙️ **Smart Algorithm** - Tự động chọn LZ4 hoặc ZSTD
- 📊 **RAM Based Sizing** - Điều chỉnh size theo RAM device
- 🔄 **Save Config** - Lưu cấu hình cho lần cài tiếp theo
- 💾 **Fallback Support** - Dự phòng bằng loop device nếu cần
- 🎯 **Unity Template** - Dễ dàng cập nhật và bảo trì

## 📦 Cài đặt

### Yêu cầu
- Magisk 15.3 trở lên
- Android 5.0+ (API 21+)
- Root access

### Cài đặt qua Magisk Manager

1. **Tải module** về thiết bị
   ```
   https://gitlab.com/disa12311/zram-manager/-/releases
   ```

2. **Mở Magisk Manager**
   - Vào tab "Modules"
   - Chọn "Install from storage"
   - Chọn file ZIP đã tải

3. **Chọn cấu hình**
   - **Vol(+)** = Enable zRAM (khuyến nghị)
   - **Vol(-)** = Disable zRAM

4. **Reboot** thiết bị

### Cài đặt qua TWRP

```bash
# Flash ZIP trong TWRP
1. Copy ZIP vào storage
2. Install → Select ZIP
3. Swipe to flash
4. Reboot system
```

### Cài đặt qua ADB (Development)

```bash
# Clone repository
git clone https://gitlab.com/disa12311/zram-manager.git
cd zram-manager

# Build module
make build

# Install to device
make install-adb

# Reboot
adb reboot
```

## 🎯 Cấu hình

Module tự động cấu hình dựa trên RAM:

| RAM Device | zRAM Size | Compression | Swappiness |
|------------|-----------|-------------|------------|
| > 3GB      | 2048 MB   | LZ4/ZSTD    | 100        |
| > 2GB      | 1792 MB   | LZ4/ZSTD    | 100        |
| > 1GB      | 1024 MB   | LZ4         | 100        |
| < 1GB      | 768 MB    | LZ4         | 100        |

### Compression Algorithms

Module tự động chọn thuật toán nén tốt nhất:
- **ZSTD**: Nếu kernel hỗ trợ (tỷ lệ nén cao hơn)
- **LZ4**: Fallback (tốc độ cao hơn)

### Manual Configuration

Cấu hình được lưu tại `/data/adb/swap-config.txt`:
```bash
# 1 = Enable zRAM
# 0 = Disable zRAM
echo "1" > /data/adb/swap-config.txt
```

## 📊 Kiểm tra trạng thái

### Via ADB

```bash
# Check swap status
adb shell cat /proc/swaps

# Check zRAM info
adb shell cat /proc/meminfo | grep -i swap

# Check compression algorithm
adb shell cat /sys/block/zram0/comp_algorithm

# Check zRAM stats
adb shell cat /sys/block/zram0/mm_stat
```

### Via Terminal Emulator

```bash
# Check swap
cat /proc/swaps

# Check memory info
free -h

# Check zRAM details
cat /sys/block/zram*/mm_stat
```

## 🔧 Development

### Build từ source

```bash
# Clone repository
git clone https://gitlab.com/disa12311/zram-manager.git
cd zram-manager

# Run tests
make test

# Check code quality
make lint

# Build module
make build

# Create release packages
make release
```

### Makefile Commands

```bash
make help           # Show all commands
make build          # Build flashable ZIP
make test           # Run tests
make check          # Run shellcheck
make lint           # Run all checks
make clean          # Clean build files
make install-adb    # Install via ADB
make device-info    # Show device info
```

### GitLab CI/CD

Pipeline tự động:
1. **Validate** - Kiểm tra cấu trúc module
2. **Lint** - Shellcheck + format check
3. **Test** - Chạy test suite
4. **Build** - Build module ZIP
5. **Package** - Tạo checksums + metadata
6. **Deploy** - Deploy documentation + releases

## 🐛 Troubleshooting

### zRAM không hoạt động

```bash
# Check kernel support
cat /proc/config.gz | gunzip | grep ZRAM

# Manual enable
zramctl --find --size 1024M
mkswap /dev/zram0
swapon /dev/zram0
```

### Module không cài được

1. Kiểm tra Magisk version (cần 15.3+)
2. Xóa module cũ trước khi cài mới
3. Flash trong recovery nếu bootloop

### Kiểm tra logs

```bash
# Magisk logs
adb shell cat /cache/magisk.log

# Or
adb shell cat /data/cache/magisk.log

# Module logs
adb shell cat /data/adb/modules/zram_config/
```

## 📈 Performance

### Benchmarks

| Device | RAM | zRAM | Apps in BG | Improvement |
|--------|-----|------|------------|-------------|
| Low-end | 2GB | 1.5GB | 8-10 | +40% |
| Mid-range | 4GB | 2GB | 12-15 | +30% |
| High-end | 6GB | 2GB | 15-20 | +20% |

### Before/After Comparison

**Without zRAM:**
- 5-6 apps in background
- Frequent app reloads
- Aggressive LMK (Low Memory Killer)

**With zRAM:**
- 10-15 apps in background
- Smoother multitasking
- Better memory management

## 🔗 Links

- **GitLab**: https://gitlab.com/disa12311/zram-manager
- **Issues**: https://gitlab.com/disa12311/zram-manager/-/issues
- **Releases**: https://gitlab.com/disa12311/zram-manager/-/releases
- **XDA Thread**: https://forum.xda-developers.com/...

## 📝 Changelog

### v1.3 (20.08.2019)
- Unity template update 4.4
- Bug fixes

### v1.2 (14.04.2019)
- Unity template update 4.0
- Magisk 19 support

### v1.1 (18.03.2019)
- Bug fixes

### v1.0 (11.03.2019)
- First release

## 🤝 Contributing

Contributions are welcome! Please:

1. Fork repository
2. Create feature branch
3. Make changes
4. Run tests: `make test`
5. Submit merge request

## 📄 License

GPL-3.0 License - xem [LICENSE](LICENSE)

## 👨‍💻 Author

- **korom42**
- XDA: https://forum.xda-developers.com/...

## 🙏 Credits

- **topjohnwu** - Magisk
- **Zackptg5** - Unity Template
- **Android Linux Kernel Team** - zRAM implementation

## ⭐ Support

Nếu module này hữu ích, hãy:
- ⭐ Star trên GitLab
- 📢 Chia sẻ với bạn bè
- 💬 Feedback trên XDA thread

---

**Disclaimer:** Module này thay đổi cấu hình hệ thống. Sử dụng tự chịu trách nhiệm.