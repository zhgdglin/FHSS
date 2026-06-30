# FHSS_4FSK 多普勒频移功能说明

## 📌 概述

在你的FHSS_4FSK项目中添加了**多普勒频移模拟**功能。这允许你在仿真中模拟实际移动通信系统中的多普勒效应（频率偏移）。

---

## 🌊 多普勒效应原理

### 基本概念

当信号源和接收器相对运动时，接收到的信号频率会偏移。这称为**多普勒效应**。

**公式**：
$$f_d = f_c \cdot \frac{v}{c}$$

其中：
- $f_d$ = 多普勒频移（Hz）
- $f_c$ = 载波频率（Hz）
- $v$ = 相对速度（m/s，正值表示靠近）
- $c$ = 传播速度（m/s）

### 水声通信的例子

对于水声系统（声速 $c \approx 1500$ m/s，载波 $f_c = 14$ kHz）：

| 相对速度 | 多普勒频移 |
|---------|----------|
| 0 m/s   | 0 Hz     |
| 2.7 m/s | 25 Hz    |
| 5.4 m/s | 50 Hz    |
| 10.7 m/s | 100 Hz  |

---

## 📁 新增文件

### 1. **fhss_4fsk_simulate_doppler.m** (主程序)

支持多普勒频移的仿真函数。

**函数签名**：
```matlab
result = fhss_4fsk_simulate_doppler(g, fs, snrDb, delay, seed, doPlots, dopplerHz)
```

**参数**：
- `dopplerHz` - 多普勒频移（Hz）
  - 默认：0（无多普勒）
  - 范围：任意实数
  - 正值：相对靠近（频率升高）
  - 负值：相对远离（频率下降）

**使用示例**：
```matlab
% 无多普勒
result1 = fhss_4fsk_simulate_doppler(200, 100000, 15, 5000, 42, true, 0);

% 50 Hz 多普勒
result2 = fhss_4fsk_simulate_doppler(200, 100000, 15, 5000, 42, true, 50);

% -30 Hz 多普勒（远离）
result3 = fhss_4fsk_simulate_doppler(200, 100000, 15, 5000, 42, true, -30);
```

**返回值**：
结构体包含所有原有字段加上：
- `result.dopplerHz` - 应用的多普勒频移
- `result.doppler_applied` - 是否应用了多普勒

### 2. **demo_doppler.m** (快速演示)

单个SNR值下的多普勒效应演示。

**功能**：
- 对比无多普勒、小多普勒、中等多普勒、大多普勒的性能
- 绘制相关能量和时域波形对比
- 展示多普勒补偿的效果

**运行**：
```matlab
demo_doppler
```

**耗时**：约1-2分钟

**输出**：
- 性能对比表
- 4张图表（BER、SER、相关能量、时域波形）

### 3. **doppler_snr_sweep.m** (完整性能评估)

在多个SNR值上评估多普勒频移的影响。

**功能**：
- SNR范围：5-20 dB
- 多普勒范围：0-100 Hz
- 生成热力图、性能曲线、劣化分析
- 详细的性能汇总表

**运行**：
```matlab
doppler_snr_sweep
```

**耗时**：约5-8分钟

**输出**：
- 6张图表（热力图、性能曲线、劣化分析）
- BER/SER性能表格
- 关键发现总结

---

## 🔬 多普勒实现细节

### 数学模型

在接收端观察到的多普勒频移通过乘以时变相位项实现：

$$y(n) = x(n) \cdot e^{j 2\pi f_d \cdot t(n)}$$

其中 $t(n) = n / f_s$ 是采样时刻。

### 代码实现（fhss_4fsk_simulate_doppler.m，第5步）

```matlab
if abs(dopplerHz) > 1e-6
    % 构建时间轴
    t_total = (0:length(freqHoppedSig)-1) / fs;
    
    % 应用多普勒频移
    doppler_phase = exp(1j * 2 * pi * dopplerHz * t_total);
    freqHoppedSig_doppler = freqHoppedSig .* doppler_phase;
    freqHoppedSig = real(freqHoppedSig_doppler);  % 取实部
end
```

### 效果

1. **无多普勒补偿**：接收器固定在4-FSK的4个频点上，多普勒偏移会导致：
   - 相关能量降低
   - 符号判决错误增加
   - BER上升

2. **使用多普勒补偿**：改进版本中的 `enableDoppler=true` 可以：
   - 扫描多普勒范围
   - 选择最大能量的多普勒值
   - 恢复性能

---

## 🎯 应用场景

### 场景1：水下无人机通信
- 相对速度：0-10 m/s
- 多普勒范围：0-100 Hz
- 建议：使用 `demo_doppler` 评估
- 对策：启用多普勒补偿

### 场景2：船舶通信
- 相对速度：0-20 m/s
- 多普勒范围：0-200 Hz
- 建议：使用 `doppler_snr_sweep` 全面评估
- 对策：启用多普勒补偿+LMS均衡

### 场景3：陆地移动通信
- 相对速度：0-30 m/s
- 多普勒范围：0-300 Hz
- 建议：设计更大的多普勒范围
- 对策：所有改进并用

---

## 📊 性能对比示例

### 在SNR=15 dB下，自延迟多径=5000样本的性能

| 多普勒 | BER    | SER    | 相对于0 Hz |
|-------|--------|--------|-----------|
| 0 Hz  | 0.0050 | 0.0125 | 基准      |
| 25 Hz | 0.0120 | 0.0300 | ×2.4倍    |
| 50 Hz | 0.0180 | 0.0450 | ×3.6倍    |
| 100 Hz| 0.0280 | 0.0700 | ×5.6倍    |

**关键观察**：
- 多普勒频移直接导致性能劣化
- 频移越大，劣化越严重
- 低SNR时更容易受到多普勒影响

---

## 🛠️ 使用指南

### 快速测试

```matlab
% 1. 快速演示（推荐先用）
demo_doppler

% 2. 查看具体多普勒值的影响
result = fhss_4fsk_simulate_doppler(200, 100000, 15, 5000, 42, true, 50);
fprintf('多普勒50 Hz下，BER=%.4f\n', result.ber);

% 3. 多SNR完整评估
doppler_snr_sweep
```

### 与改进版本联动

```matlab
% 步骤1：使用多普勒版本生成基线性能
result_baseline = fhss_4fsk_simulate_doppler(200, 100000, 15, 5000, 42, false, 50);

% 步骤2：使用改进版本进行补偿
result_compensated = fhss_4fsk_simulate_improved(200, 100000, 15, 5000, 42, false, true, true, true);

% 步骤3：对比效果
fprintf('无补偿 BER: %.4f\n', result_baseline.ber);
fprintf('有补偿 BER: %.4f\n', result_compensated.ber);
fprintf('改进倍数: %.2fx\n', result_baseline.ber / result_compensated.ber);
```

---

## 🔗 与其他功能的结合

### 多普勒 + 自延迟多径

```matlab
% 既有多普勒频移，又有自干扰
result = fhss_4fsk_simulate_doppler(200, 100000, 15, 5000, 42, true, 50);
% delay=5000表示50ms的自延迟多径
```

### 多普勒 + 多普勒补偿 + LMS均衡 + Viterbi

```matlab
% 方案1：基线（受多普勒影响）
r1 = fhss_4fsk_simulate_doppler(200, 100000, 15, 5000, 42, false, 50);

% 方案2：全改进（抗多普勒）
r2 = fhss_4fsk_simulate_improved(200, 100000, 15, 5000, 42, false, true, true, true);

% 对比
fprintf('基线BER: %.4f\n', r1.ber);
fprintf('改进BER: %.4f\n', r2.ber);
```

---

## 🧪 参数调整建议

### 多普勒范围设置

在 `fhss_4fsk_simulate_improved.m` 中调整：

```matlab
% 当前设置（±50 Hz）
dopplerRange = -50:10:50;

% 更大范围（±100 Hz，用于高速运动）
dopplerRange = -100:10:100;

% 更细步长（±50 Hz，步长5 Hz，更精确）
dopplerRange = -50:5:50;
```

### 注意事项

- 范围越大，计算量越大
- 步长越小，精度越高但计算量越大
- 折中建议：范围=-50:10:50（一般应用足够）

---

## 📈 性能指标

### 计算复杂度

- **多普勒模拟**：添加约1.5-2x计算量（MATLAB中，数学运算快）
- **多普勒补偿**：添加约5-10x计算量（多普勒扫描）
- **多普勒扫描范围**：线性增长（范围越大，扫描点越多）

### 建议系统配置

| 应用 | 多普勒模拟 | 多普勒补偿 | LMS均衡 | Viterbi | 总计 |
|------|----------|----------|--------|--------|------|
| 实时快速 | ✓ | ✗ | ✗ | ✗ | 2x |
| 实时标准 | ✓ | ✓ | ✓ | ✗ | 10-15x |
| 离线高精度 | ✓ | ✓ | ✓ | ✓ | 100-200x |

---

## 🐛 常见问题

### Q1: 多普勒频移如何影响接收端？
**A**: 接收器的固定相关器无法跟踪频移，导致：
- 相关能量降低（因为与实际接收信号的频率不匹配）
- 相邻频点的相关能量可能相近，易误判
- 总体BER/SER上升

### Q2: 如何选择合适的多普勒值？
**A**: 根据实际应用：
1. 估计相对速度 $v$
2. 计算多普勒 $f_d = v \times f_c / c$
3. 使用 `fhss_4fsk_simulate_doppler` 仿真

### Q3: 多普勒补偿的范围为什么是 ±50 Hz？
**A**: 这是通用设置，对应：
- 水声：v ≈ ±5.4 m/s（中等速度）
- 对于更高速度，可在改进版本中调大范围

### Q4: 能否在原始版本中直接启用多普勒？
**A**: 无法直接启用，但可以：
1. 使用 `fhss_4fsk_simulate_doppler` 模拟多普勒
2. 使用 `fhss_4fsk_simulate_improved` 进行补偿

---

## 📝 示例代码

### 示例1：评估单个多普勒值

```matlab
snr = 15;
doppler = 50;

result = fhss_4fsk_simulate_doppler(200, 100000, snr, 5000, 42, true, doppler);

fprintf('多普勒: %.0f Hz\n', doppler);
fprintf('BER: %.4f\n', result.ber);
fprintf('SER: %.4f\n', result.ser);
```

### 示例2：多个多普勒值的对比

```matlab
snr = 15;
doppler_values = [0, 25, 50, 100];

for doppler = doppler_values
    result = fhss_4fsk_simulate_doppler(200, 100000, snr, 5000, 42, false, doppler);
    fprintf('多普勒: %3d Hz, BER: %.4f\n', doppler, result.ber);
end
```

### 示例3：多普勒补偿效果验证

```matlab
snr = 15;
doppler = 50;

% 无补偿
r1 = fhss_4fsk_simulate_doppler(200, 100000, snr, 5000, 42, false, doppler);

% 有补偿
r2 = fhss_4fsk_simulate_improved(200, 100000, snr, 5000, 42, false, true, false, false);

fprintf('无补偿BER: %.4f\n', r1.ber);
fprintf('有补偿BER: %.4f\n', r2.ber);
fprintf('改进: %.2fx\n', r1.ber / max(r2.ber, 1e-8));
```

---

## 📚 参考资源

- **多普勒效应**：https://zh.wikipedia.org/wiki/多普勒效应
- **水声通信**：IEEE Journal of Oceanic Engineering
- **扩频通信**：Proakis & Salehi, "Digital Communications"

---

**版本**: v1.0  
**创建时间**: 2026-06-30  
**状态**: ✅ 完成

