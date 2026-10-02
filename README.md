# 电控第一次作业

姓名：＿＿＿　学号：＿＿＿

芯片：STM32F103C8T6（F103 最小系统板）
工程：CubeMX 生成，Toolchain/IDE 选 CMake，构建类型 **Debug**
业务代码全部放在 `Tasks/`，`main.c` 里只在 USER CODE 区包含头文件并调用初始化，
`while (1)` 保持为空。

## 工程结构

```
Core/            CubeMX 生成，不手改（tim.c 的 PSC/ARR 由 .ioc 决定）
Tasks/inc/       Task_Timer.h  Tasks_GPIO.h
Tasks/src/       Task_Timer.c  Tasks_GPIO.c   ← 业务代码只写在这里
NO1homework.ioc  CubeMX 配置（TIM2 PSC/ARR、IWDG 都在这里）
build/           Debug 构建产物，Ozone 打开 build/NO1homework.elf
```

重新用 CubeMX 生成代码后，若模板 `CMakeLists.txt` 被覆盖，换回发放的那一份
（`user_folders` 保持 `"Tasks"`）。自己的代码在 `Tasks/` 和 USER CODE 区，生成不会冲掉。

---

## 第 1 题　GPIO

PC13 配成推挽输出，初始化时写入低电平，板载 LED 点亮。不在 `while (1)` 里翻转。

`Tasks/src/Tasks_GPIO.c`：

```c
void Task_GPIO_Init(void) {
    HAL_GPIO_WritePin(GPIOC, GPIO_PIN_13, GPIO_PIN_RESET);
}
```

本课题还没喂狗，暂停后约 2 秒内要看完，否则芯片复位、调试器掉线。

---

## 第 2 题　定时器（1 ms 更新中断）

### 定时器时钟从哪来

时钟树（`RCC.APB1TimFreq_Value = 72000000`，CubeMX 时钟树显示值）：

| 环节 | 设置 | 频率 |
|---|---|---|
| HSE 晶振 | 外部 8 MHz | 8 MHz |
| PLL | 源 HSE，倍频 ×9 | 72 MHz |
| SYSCLK | 选 PLLCLK | 72 MHz |
| AHB 预分频 | ÷1 | HCLK = 72 MHz |
| APB1 预分频 | ÷2 | PCLK1 = 36 MHz |

TIM2 挂在 **APB1** 上。STM32F1 参考手册规定：**当 APB 预分频系数不为 1 时，
挂在该总线上的定时器时钟为该 APB 时钟的 2 倍**。这里 APB1 是 ÷2，所以

```
TIM2 时钟 = PCLK1 × 2 = 36 MHz × 2 = 72 MHz
```

（若 APB1 分频为 1，则 TIM2 时钟就等于 PCLK1，不存在这个翻倍。）

### PSC、ARR 的计算

更新中断周期公式：

```
(PSC + 1) × (ARR + 1) / 定时器时钟 = 周期
```

要 1 ms：

```
(PSC + 1) × (ARR + 1) = 0.001 s × 72 000 000 Hz = 72 000
```

把 72000 拆成两个整数，取值时让 PSC 尽量小以保留计数精度：

```
PSC + 1 = 72   →   PSC = 71
ARR + 1 = 1000 →   ARR = 999
```

验证：`72 × 1000 / 72 000 000 = 0.001 s = 1 ms` ✓

（CubeMX 里 TIM2 的 Prescaler 填 **71**、Counter Period 填 **999**。注意 Prescaler 这一栏
CubeMX 填的是 PSC 本身，不要填 72。）

### 回调

赋值要求变量名必须叫 `tick`，定义成全局 `volatile uint32_t`，这样 Debug 下
Ozone 才能在 Watch / Timeline 里看到它。

`Tasks/src/Task_Timer.c`：

```c
#include "Task_Timer.h"
#include "iwdg.h"

// 第2题: 必须是全局 volatile uint32_t, Debug 下 Ozone 才看得到
// TIM2 更新中断周期 1ms -> 每秒约 +1000
// PSC=71, ARR=999: (71+1)*(999+1)/72MHz = 72000/72MHz = 0.001s
volatile uint32_t tick = 0;

void HAL_TIM_PeriodElapsedCallback(TIM_HandleTypeDef *htim) {
    if (htim->Instance == TIM2) {
        tick++;
        HAL_IWDG_Refresh(&hiwdg);   // 第3题: 把这行注释掉, 重新编译下载
    }
}
```

定时器更新回调全工程只写这一份。`main.c` 和 `stm32f1xx_it.c` 里没有同名函数，
否则链接会报重复定义。

`main.c` 的 USER CODE 区里启动定时器：

```c
MX_TIM2_Init();
/* USER CODE BEGIN 2 */HAL_TIM_Base_Start_IT(&htim2); // 开启定时器中断
```

`tick` 只在中断里自增，没有用 `HAL_Delay`，也没有空循环。

---

## 第 3 题　看门狗（IWDG）

### 超时的计算

LSI 按手册取值，F103 约 **40 kHz**。

```
超时 = (Reload + 1) × 分频 / LSI
```

取分频 64、Reload 1249：

```
(1249 + 1) × 64 / 40 000 = 80 000 / 40 000 = 2.0 s
```

（CubeMX 里 IWDG 的 Prescaler 选 `IWDG_PRESCALER_64`，Reload 填 **1249**。
对应 `NO1homework.ioc` 里 `IWDG.Prescaler=IWDG_PRESCALER_64`、`IWDG.Reload=1249`。）

超时 2 s 明显长于 1 ms 的中断周期，否则 `tick` 还来不及增加就被清掉。

### 做法与现象

IWDG 保持启用，超时和分频都不改。把回调里那一行 `HAL_IWDG_Refresh(&hiwdg);`
注释掉，重新编译、重新下载。

预期现象：`tick` 从 0 涨到大约 **2000**，然后回到 0，如此反复。
回到 0 是因为复位后启动代码把全局变量清零。

用 Ozone 看的时候要**让程序跑着，不要停在断点上**——CPU 停住时看门狗仍在计数，
超过 2 秒调试器就会掉线。

---

## 附录：截图与照片

（说明文档只在附录放图，正文不插图。）

1. **GPIO**：板载 LED 点亮的照片。
2. **定时器**：Ozone 的 Watched Data 或 Timeline 截图，程序处于运行状态，
   能看出 `tick` 大约每秒增加 1000。
3. **看门狗**：Ozone 的 Timeline 或连续监视窗口截图，能看到 `tick` 涨上去再归零。
