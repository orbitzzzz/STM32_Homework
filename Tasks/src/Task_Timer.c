#include "Task_Timer.h"
#include "iwdg.h"

// 第2题: 必须是全局 volatile uint32_t, Debug 下 Ozone 才看得到
// TIM2 更新中断周期 1ms -> 每秒约 +1000
// PSC=71, ARR=999: (71+1)*(999+1)/72MHz = 72000/72MHz = 0.001s
volatile uint32_t tick = 0;

void HAL_TIM_PeriodElapsedCallback(TIM_HandleTypeDef *htim) {
    if (htim->Instance == TIM2) {
        tick++;
        
       // HAL_IWDG_Refresh(&hiwdg);   // 第3题: 把这行注释掉, 重新编译下载
    }
}