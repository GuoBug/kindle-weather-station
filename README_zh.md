# Kindle 电子墨水屏天气时钟看板

[![License](https://img.shields.io/github/license/gu0bug/kindle-weather-station)](LICENSE)
[![GitHub tag (latest by date)](https://img.shields.io/github/v/tag/gu0bug/kindle-weather-station?color=blue&label=release)](https://github.com/gu0bug/kindle-weather-station/releases)
[![GitHub repo size](https://img.shields.io/github/repo-size/gu0bug/kindle-weather-station)](https://github.com/gu0bug/kindle-weather-station)
![Platform](https://img.shields.io/badge/Platform-Kindle-orange)
![KUAL](https://img.shields.io/badge/KUAL-Supported-brightgreen)
[![GitHub stars](https://img.shields.io/github/stars/gu0bug/kindle-weather-station?style=social)](https://github.com/gu0bug/kindle-weather-station/stargazers)
[![GitHub forks](https://img.shields.io/github/forks/gu0bug/kindle-weather-station?style=social)](https://github.com/gu0bug/kindle-weather-station/network/members)

本项目将一部已越狱的 Amazon Kindle 变成一个低功耗、独立的桌面天气时钟看板。使用 Python Pillow (PIL) 图形库进行画面绘制，生成高对比度、适合电子墨水屏的画面，包含 LCD 3D 拟真 7 段数码管时钟、极简天气矢量图标以及详细的天气实况与预报。

看板提供了底部状态栏触摸控制按钮，支持即时旋转屏幕方向、切换中英文显示以及退出看板回到 Kindle 原生系统。

---

## 演示效果

| 竖屏模式 (默认) | 横屏模式 |
|---|---|
| ![竖屏](images/portrait.jpg) | ![横屏](images/landscape.jpg) |

---

## 功能特性

- **双模功耗切换**：
  - **节能模式 (Eco Mode，默认)**：彻底取消秒级心跳波形刷新，对齐 1 分钟整分刷新，天气数据 30 分钟同步一次（夜间 1 小时），大幅降低墨水屏翻转与 Wi-Fi 功耗，续航可延长数倍。
  - **性能模式 (Performance Mode)**：保持时钟冒号心跳闪烁（展现 7 秒、熄灭 3 秒），天气数据 10 分钟同步，屏幕响应更灵动。
  - **即时切换**：状态栏新增 **节能/性能** 触摸按钮，随时一键无感切换。
- **横竖切换**：支持**竖屏**（758x1024，默认）与**横屏**（1024x758，顺时针旋转90度以适配 Kindle 的竖屏硬件缓冲区）即时切换。
- **中英双语**：状态栏一键切换显示语言（星期、日期、天气描述以及按钮文本）。
- **前光控制**：状态栏一键开关前光背光。
- **极简 7 段数码管时钟**：通过数学几何绘制数码管段，无需依赖外部字体文件即可渲染出清晰厚重的 LCD 效果。
- **极简天气图标**：纯矢量绘制天气、日出、日落图标，完美融入 E-ink 墨水屏。
- **安全凭据隔离**：支持通过 `user_config.sh` 或环境变量注入 API Key，不在系统命令行暴露敏感信息。
- **自动退出**：插上 USB 充电或连接电脑时，看板守护进程会自动检测并干净地退出，恢复 Kindle 原生 GUI 系统。
- **缓存机制**：天气预报数据本地缓存，旋转屏幕与切换语言在 1 秒内即时响应，不消耗网络流量和 API 额度。
- **作者署名**：在状态栏底部居中渲染小字署名 `" by Guo Qiang"`。

---

## 硬件与软件要求

1. **已越狱的 Kindle**：带有触摸屏的 Kindle 设备（如 Paperwhite 2/3/4、Voyage、Oasis 等）。
2. **KUAL (Kindle Unified Application Launcher)**：用于启动脚本插件。
3. **Python 3.9+ 运行环境**：Kindle 上需安装 `/mnt/us/python3`（包含 `Pillow` 库的越狱包）。
4. **无线网络**：配置好 Kindle 连接到本地 Wi-Fi 以前往 OpenWeatherMap API 获取数据。

---

## 文件目录结构

```text
weather-station/
├── config.xml         # KUAL 插件配置文件
├── menu.json          # KUAL 启动菜单
├── weather.sh         # 主守护进程脚本（电源管理与循环控制）
├── render.py          # Python Pillow 图形渲染脚本
├── monitor_touch.py   # 触摸屏输入解码与按钮监听工具
└── images/            # 屏幕截图和演示媒体文件
```

---

## 配置与部署

1. **获取 OpenWeatherMap API Key**：前往 [OpenWeatherMap](https://openweathermap.org/) 注册免费账户并获取 API Key。
2. **配置私有参数**（推荐创建 `user_config.sh`，避免污染主脚本）：
   新建或编辑 `user_config.sh`：
   ```bash
   API_KEY="您的_OPENWEATHERMAP_API_KEY"
   CITY_NAME="Shanghai,CN"  # 您的城市代码
   POWER_MODE="eco"         # 默认运行模式："eco"（节能）或 "perf"（性能）
   INTERVAL=1800            # 节能模式下天气刷新周期（秒）
   ```
3. **拷贝至 Kindle**：
   - 将 Kindle 通过 USB 连接至电脑。
   - 将 `weather-station` 整个文件夹拷贝到 Kindle 根目录下的 `extensions` 目录中：
     `[Kindle 根目录]/extensions/weather-station/`
   - **非常重要**：请确保所有文件（尤其是 `weather.sh` 脚本和 python 文件）都使用 **Unix (LF)** 换行符。Windows 上的 CRLF 换行符会导致 Kindle shell 报错。

---

## 使用说明

1. 安全弹出 Kindle 并拔掉 USB 数据线。
2. 启动 Kindle 上的 **KUAL**。
3. 点击 **Weather Station** -> **Start Weather Station**。
4. 看板会自动运行并接管屏幕。
5. 屏幕底部状态栏提供 5 个即时触摸控制按钮：
   - **旋转 / Rotate**：切换横屏或竖屏方向。
   - **节能 / 性能 (Eco / Perf)**：在超长续航整分对齐模式与心跳闪烁模式间切换。
   - **灯:开 / 灯:关 (Light / Dark)**：开启或关闭屏幕前光。
   - **中/EN**：切换中文与英文界面。
   - **退出 / Exit**：安全退出看板并恢复 Kindle 原生阅读器界面。

---

## 许可证

本项目开源且免费使用。由 **Guo Qiang** 优化定制。
