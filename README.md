# Cyber Bunker — Godot MVP

一个 Godot 4 像素原型：地堡采用可自由扩建的横截面网格，外部探索采用 DNF 式横版纵深地下城。场景与 UI 全部由 GDScript 程序化绘制，角色采用授权像素 sprite（`AnimatedSprite2D`）。

## 运行

用 Godot 4.6+ 打开项目并运行，或在项目目录执行：

```sh
godot --path .
```

## 操作

- `A / D` 或左右方向键：在地堡楼层内移动
- 电梯处按 `W / S`：切换地堡楼层
- `Tab`：开启或关闭地堡设计模式
- 设计模式中按 `1–5` 或点击底部蓝图：选择房间
- 设计模式中左键：建造或替换房间；右键：拆除房间；`R`：恢复默认布局
- `W / A / S / D` 或方向键：在地下城中进行横向与纵深移动
- 地堡顶层最右侧气闸：打开外部关卡地图
- 出门后使用 `A / D` 或方向键选择关卡，按 `Enter` 部署；也可以直接点击地图节点
- 关卡地图按 `Esc` 返回地堡
- 地下城房间左右边缘：前进、返回上一区域或回到关卡地图
- 战斗：`J` 三段基础连击，`K` 赛博横扫技能，`L` 无敌帧闪避
- 击败当前房间全部敌人后右侧闸门解锁；最终房间通关后按 `Enter` 带战利品回地堡
- `U / I / O / P / ;` 为后续技能栏预留键位；消耗品栏为 `Q / E`

相邻的同类房间会自动连成扩展房间。再次点击同类房间会消耗战利品升级，最高等级和费用来自房间 Resource。布局自动保存到 Godot 的 `user://bunker_layout.json`。

关卡、敌人和房间配置位于 `data/` 下的 Godot `.tres` Resource；新增内容不需要修改核心控制器中的数值表。

## 美术素材

地堡 / 地下城场景、HUD 与特效均为程序化绘制。地堡为半地上半地下结构：顶层在地面之上，透过窗户可见城市天际线，并设有地面入口；其余楼层埋于地下。

角色 sprite 使用 CraftPix 的 "3 Cyberpunk Characters"（经 OpenGameArt 分发，授权 **OGA-BY 3.0**，需署名），位于 `assets/cyberpunk_chars/`；地堡窗外的城市天际线使用 CraftPix 的 "Cyberpunk Backgrounds Pixel Art"（同为 **OGA-BY 3.0**），位于 `assets/backgrounds/`。两处署名分别见各目录下的 `CREDITS.md`。`scripts/art/character_frames.gd` 将动画条切成 `SpriteFrames`，玩家与敌人通过 `AnimatedSprite2D` 播放 idle/run/attack/hurt/death。
