# 拔萝卜游戏素材

可直接导入 Godot 的 PNG 放在 [`assets/carrot_game/`](assets/carrot_game/)；场景基准尺寸为 **1920×1080**。除 `bg_sky.png` 外，所有 PNG 均带透明通道。`source_generated/` 是生成原图，`export_carrot_assets.ps1` 用于统一尺寸并导出 PNG。

## 推荐图层顺序（由后到前）

1. `bg_sky.png`
2. `bg_cloud_01.png`～`bg_cloud_03.png`（各自飘动）
3. `bg_fence.png`
4. `bg_soil_back.png`
5. 代码绘制的左右绿色目标扇形
6. `carrot_full.png` 与同位置的 `carrot_crack_*.png`
7. `bg_soil_front.png`（遮住地下的萝卜身子）
8. `soil_crack_*.png`（叠加在土面）
9. `bg_plants_front.png`、一张 `rabbit_*.png`、特效和 UI

## 对齐坐标

| 项目 | 1920×1080 场景中的坐标或尺寸 |
| --- | --- |
| 萝卜出土点 / 推荐旋转中心 | `(960, 810)` |
| `carrot_full.png` | `400×900`；起始左上角 `(760, 370)`；中途示例 `(760, 170)` |
| `carrot_crack_1.png`～`carrot_crack_3.png` | 均为 `400×900`，与完整萝卜使用相同位置、旋转和上升量 |
| `soil_crack_1.png`～`soil_crack_4.png` | 均为 `500×150`；推荐左上角 `(710, 735)`，中心对准出土点 |
| 所有 `rabbit_*.png` | 均为 `500×450`；推荐左上角 `(1300, 390)`，切换时保持相同位置 |
| `bg_fence.png`、两层土、前景草叶 | 均为 `1920×1080`，左上角 `(0, 0)` |

萝卜从起始位置向上移动约 200 像素时，预览中露出半截。旋转时可让父节点位于 `(960, 810)`，通过子节点的局部位置控制上升量。裂纹叠加层应与完整萝卜共用同一变换。

`ui_hourglass.png` 是空玻璃外框；可将 `ui_sand.png` 放在它后面并裁切，表示剩余时间。`ui_result_panel.png` 无文字，结算文字由 Godot 添加。`fx_dirt.png`、`fx_sparkle.png` 和四种彩纸片是可选粒子素材。**未制作 `fx_sector.png`**，扇形由代码绘制，角度和亮度更容易调整。阴影与动态发光效果也由代码添加。

`previews/preview_start.png` 与 `previews/preview_mid.png` 是分层合成检查图；游戏中请使用单独的 PNG 素材。
