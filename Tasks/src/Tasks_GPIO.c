#include "Tasks_GPIO.h"

void Task_GPIO_Init(void) {
    // 按照作业要求：PC13 配成推挽输出，初始写入低电平（点亮）
    HAL_GPIO_WritePin(GPIOC, GPIO_PIN_13, GPIO_PIN_RESET);
}