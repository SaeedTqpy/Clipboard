# Clipboard — مدیریت حرفه‌ای کلیپ‌بورد macOS

**بومی، محلی و با تمرکز بر حریم خصوصی**

Clipboard یک برنامهٔ Menu Bar است که تاریخچهٔ متن، لینک، متن قالب‌بندی‌شده، تصاویر و فایل‌های کپی‌شده را در پنلی شناور و قابل جستجو نمایش می‌دهد. با **SwiftUI + AppKit** ساخته شده و از **Liquid Glass در macOS 26** و Material سیستم در macOS 15 تا 25 استفاده می‌کند.

[English README](README.md) · [دانلود](#دانلود-و-نصب) · [تصاویر برنامه](docs/SCREENSHOTS.md) · [گزارش خطا](https://github.com/SaeedTqpy/Clipboard/issues)

> **نسخهٔ پیش‌نمایش توسعه‌دهندگان — v0.2.0.** در ۱۳ نوامبر ۲۰۲۶، همهٔ **۲۹ تست خودکار** موفق شدند و خروجی Universal برای Apple Silicon و Intel ساخته شد. تست مجوز Accessibility، Paste واقعی و چندمانیتوره روی مک کاربر همچنان باقی است. این نسخه هنوز تأییدیهٔ انتشار عمومی ندارد.

## تصاویر محیط برنامه

<!-- SCREENSHOTS:START -->

هنوز اسکرین‌شات واقعیِ تأییدشده از برنامه داخل ریپو موجود نیست. برای جلوگیری از نمایش تصویر ساختگی به‌عنوان محیط واقعی نرم‌افزار، راهنمای ثبت و آپلود تصاویر در [docs/SCREENSHOTS.md](docs/SCREENSHOTS.md) و اسکریپت [capture-readme-screenshots.sh](scripts/capture-readme-screenshots.sh) آماده شده است. با آن می‌توان تصاویر واقعی پنل، جستجو و تنظیمات را از مک ثبت و در README قرار داد.

<!-- SCREENSHOTS:END -->

## قابلیت‌ها

| بخش | امکانات |
| --- | --- |
| تاریخچه | متن، لینک، HTML/RTF، تصویر و چند فایل |
| پنل شناور | نمایش افقی کارت‌ها، جستجو و دسترسی سریع |
| مدیریت | Pin، حذف، Collections و فیلتر نوع محتوا |
| چسباندن | Paste، Paste بدون فرمت و Paste Stack |
| حریم خصوصی | Monitoring اختیاری، استثناکردن اپلیکیشن‌ها، کنترل ضبط عکس و فایل |
| رمزنگاری | AES-256-GCM و Keychain برای تاریخچه و تصاویر |
| Backup | خروجی و بازیابی رمزگذاری‌شده با گذرواژه |
| ذخیره‌سازی | محدودیت تعداد و مدت سابقه و حجم تصاویر غیرپین‌شده |
| macOS | Menu Bar، Launch at Login و ظاهر بومی |

## پیش‌نیازها

- **macOS 15 یا جدیدتر**؛ Liquid Glass در **macOS 26 به بالا**.
- پردازندهٔ **Apple Silicon یا Intel**.
- نصب نسخهٔ آماده نیازی به **Xcode یا Apple Developer Account** ندارد.
- برای **Paste خودکار** مجوز **Accessibility** لازم است؛ مشاهده و Copy معمولی بدون آن کار می‌کند.

## دانلود و نصب

نسخهٔ تأییدشده در [GitHub Actions Run #43389410106](https://github.com/SaeedTqpy/Clipboard/actions/runs/43389410106) قرار دارد.

۱. در قسمت **Artifacts** فایل **Clipboard-macOS-unsigned** را دانلود کنید. برای دسترسی ممکن است ورود به GitHub لازم باشد. فایل‌ها فعلاً بعد از **۱۴ روز** منقضی می‌شوند.

۲. ZIP بیرونی و سپس `Clipboard-macOS-unsigned.zip` داخلی را باز کنید.

۳. `Clipboard.app` را به پوشهٔ **Applications** منتقل کنید و اجرا کنید.

۴. برنامه فعلاً **امضا و Notarize نشده** است؛ اگر macOS مانع اجرا شد، تنها در صورت اعتماد به خروجی، مسیر **System Settings → Privacy & Security → Open Anyway** را بررسی کنید.

۵. تست اولیه را با داده‌های ساختگی مثل `Clipboard test 001` انجام دهید. برنامه در نصب تازه **با Monitoring خاموش** شروع می‌شود.

برای ساخت خروجی جدید، از [Workflow دستی](https://github.com/SaeedTqpy/Clipboard/actions/workflows/macos.yml) گزینهٔ **Run workflow** را بزنید. اجرای خودکار روی Push غیرفعال است.

## آموزش سریع

۱. برنامه را باز کنید و آیکون را در **Menu Bar** ببینید.

۲. با **⌘⇧V** پنل تاریخچه را باز کنید.

۳. Monitoring را فعال کرده و متنی آزمایشی در Notes کپی کنید.

۴. از جستجو و دکمهٔ **Copy** برای بازیابی متن استفاده کنید.

۵. برای Paste مستقیم به برنامهٔ دیگر، دسترسی **Accessibility** را در تنظیمات macOS فعال کنید.

۶. از منوی کارت‌ها برای **Pin، Move to Collection، Add to Paste Stack، Paste as Plain Text** و حذف استفاده کنید.

| میانبر | عملکرد |
| --- | --- |
| **⌘⇧V** | باز و بسته‌کردن پنل |
| **⌘1 تا ⌘9** | Paste آیتم‌های اول قابل مشاهده، در صورت دریافت میانبر توسط پنل |
| **Esc** | بستن پنل |

میانبر اصلی فعلاً ثابت است و ممکن است با برخی برنامه‌ها تداخل داشته باشد.

## امنیت و حریم خصوصی

- تاریخچه **فقط روی دستگاه** نگهداری می‌شود و برنامه سرویس Sync، Analytics یا ارسال خودکار محتوا به شبکه ندارد.
- متن‌ها، مسیر فایل‌ها، پیش‌نمایش‌ها و تصاویر ذخیره‌شده با **AES-GCM** رمزگذاری می‌شوند؛ اما محتوای فعال در RAM و کلیپ‌بورد خود macOS الزاماً رمزگذاری‌شده نیست.
- تشخیص برنامه‌های مدیریت رمز عبور و داده‌های محرمانه **به‌صورت Best Effort** انجام می‌شود؛ ضبط ناخواستهٔ رازها همچنان ممکن است.
- پاک‌شدن تاریخچه به معنی حذف قطعی از Backup قدیمی، APFS Snapshot یا حافظهٔ SSD نیست.
- از دست‌رفتن کلید Keychain ممکن است بازیابی تاریخچهٔ محلی را غیرممکن کند. برای انتقال به مک دیگر، از **Backup رمزگذاری‌شده با رمز مستقل** استفاده کنید.
- Backup صرفاً **مسیر فایل‌های خارجی** را ذخیره می‌کند، نه دادهٔ داخل آن فایل‌ها.
- نسخهٔ فعلی هنوز Sandbox و امضای دیجیتال برای توزیع عمومی ندارد.

**هنگام کار با رمز عبور، کلید خصوصی، توکن و اطلاعات حساس، Monitoring را غیرفعال کنید.**

جزئیات: [SECURITY.md](SECURITY.md) · [معماری](docs/ARCHITECTURE.md)

محل داده‌های برنامه: `~/Library/Application Support/Clipboard/`

## توسعه

برای Build محلی، Xcode و XcodeGen لازم‌اند:

```bash
brew install xcodegen
xcodegen generate --spec project.yml
xcodebuild test -project Clipboard.xcodeproj -scheme Clipboard \
  -configuration Debug -destination 'platform=macOS' CODE_SIGNING_ALLOWED=NO
```

بدون Xcode محلی از GitHub Actions دستی استفاده کنید.

[راهنمای مشارکت](CONTRIBUTING.md) · [برنامهٔ توسعه](docs/ROADMAP.md) · [تست دستگاه](docs/MAC_DEVICE_QA.md)

**مجوز انتشار:** پروژه هنوز فایل LICENSE ندارد. قابل مشاهده بودن سورس در GitHub به معنی اجازهٔ بازنشر یا استفادهٔ مشتق نیست.

---

Clipboard یک پروژهٔ مستقل است و وابستگی رسمی به Apple ندارد.
