# 气球关素材（gameB）

独立素材位于 `assets/balloon_game/`，合成摆位参考为根目录的 `balloon_game_preview.png`（1920×1080）。全部 30 张独立素材均为透明底 PNG，未合成地面阴影或文字。

## 坐标与图层

- 参考坐标基于 1920×1080。预览中兔子画布左上角为 `(100, 400)`，打气筒底座为 `(470, 640)`，气球吹口为 `(760, 760)`，大萝卜为 `(980, 580)`。游戏中可按镜头调整。
- 五色完整气球均为 **400×480**。吹口锚点统一为画布底边中心 **`(200, 479)`**；预览中的粉色气球以 0.7 倍显示，吹口仍落在 `(760, 760)`。
- `balloon_stretch.png` 为 400×480 的透明叠加层，应与完整气球共用变换和锚点，仅在接近爆裂阈值时显示。
- `big_carrot.png` 和 `big_carrot_fall.png` 均为 **760×300**。叶根绳结线圈的中心约为图内 **`(235, 165)`**，预览中的世界坐标约为 `(1215, 745)`；气球绳线在这里汇合。
- 五张常规兔子图均为 **500×450**，整张画布同位置切换，前爪只在 `pump_handle.png` 上。飞行图为 400×500，应作为独立动画节点。
- `pump_handle.png` 为 **260×180**，活塞杆中心约为图内 `x=130`；`pump_base.png` 为 **200×260**，筒口中心约为图内 `x=100`。预览把手位置为 `(440, 555)`，底座位置为 `(470, 640)`，可沿 Y 轴移动把手。
- 建议图层顺序：天空 → 云 → 篱笆 → 后土 → 兔子/打气筒/气球/大萝卜 → 前土 → 前景植物 → UI。气球绳、软管、虚线目标圈、进度光点和底部曲线由 Godot 绘制。

## 直接复用的拔萝卜素材

从原来的 `assets/carrot_game/` 加载 `bg_sky.png`、`bg_cloud_01.png`～`bg_cloud_03.png`、`bg_fence.png`、`bg_soil_back.png`、`bg_soil_front.png`、`bg_plants_front.png`、`ui_hourglass.png`、`ui_result_panel.png`、`fx_sparkle.png` 和 `fx_confetti_01.png`～`fx_confetti_04.png`。本文件夹没有重复存放这些文件。

`cover_balloon.png` 按要求留给选择页从合成预览裁切，因此这里没有另画。

## 文件清单

- 兔子：`balloon_rabbit_focus.png`、`balloon_rabbit_happy.png`、`balloon_rabbit_frizz.png`、`balloon_rabbit_worried.png`、`balloon_rabbit_speechless.png`、`balloon_rabbit_fly.png`
- 打气筒：`pump_base.png`、`pump_handle.png`
- 气球：`balloon_pink.png`、`balloon_yellow.png`、`balloon_blue.png`、`balloon_purple.png`、`balloon_green.png`、`balloon_stretch.png`、`balloon_flat.png`、`balloon_pop.png`
- 粒子：`fx_rubber_01.png`～`fx_rubber_03.png`、`fx_air.png`
- 大萝卜：`big_carrot.png`、`big_carrot_fall.png`
- 界面：`ui_life_balloon_on.png`、`ui_life_balloon_off.png`、`ui_slot_empty.png`、`ui_slot_pink.png`、`ui_slot_yellow.png`、`ui_slot_blue.png`、`ui_slot_purple.png`、`ui_slot_green.png`

`source_generated/` 保存原始绘图，`export_balloon_assets.ps1` 可重新导出统一尺寸的 PNG，`make_preview.ps1` 可重新合成预览。`source_map.json` 记录原始生成路径。
