# FHSS_4FSK（精简版）

这个项目已经精简为单核心仿真函数架构：
1. 一个统一仿真函数：fhss_4fsk_simulate.m
2. 一个示例入口脚本：FH_practice.m
3. 两个工具函数：Mcreate.m、Plot_f.m

现在时延、多普勒、白噪声都在同一次调用内可调，不再拆成多个仿真函数或多个演示脚本。

## 1. 精简后文件结构

保留的核心 .m 文件：
- fhss_4fsk_simulate.m：统一仿真函数（唯一核心）
- FH_practice.m：快速示例与参数入口
- FH_env_config.m：共享环境配置（白噪声/时延/多普勒复用）
- experiment_ber_ser.m：仅 BER/SER 实验
- experiment_sync_success.m：仅同步成功率实验
- Mcreate.m：伪随机序列生成
- Plot_f.m：频谱绘图

## 2. 统一参数模型

统一接口：

```matlab
result = fhss_4fsk_simulate(g, fs, snrDb, delay, seed, doPlots, opts)
```

基础参数：
- g：比特数
- fs：采样率
- snrDb：白噪声强度（AWGN 的 SNR）
- delay：时延多径样本数
- seed：随机种子
- doPlots：是否绘图

扩展参数（opts 结构体）：
- dopplerHz：多普勒频移（Hz）
- enableDopplerComp：是否启用多普勒补偿扫描
- dopplerCompRange：补偿扫描范围（默认 -50:10:50）
- enableLMS：是否启用 LMS 均衡
- lmsMu：LMS 步长
- lmsFilterLen：LMS 滤波器长度
- enableViterbi：是否启用 Viterbi 解码
- symbolDurationMs：每个 MFSK 符号有效时长（毫秒）
- guardIntervalMs：每个符号后的保护间隔（毫秒）
- symbolSamples 会由 fs 和 symbolDurationMs 自动换算
- freqs：4FSK 频点数组

## 3. 快速使用

直接运行：

```matlab
FH_practice
```

或者自己调用：

```matlab
g = 200;
fs = 100000;
snrDb = 12;      % 白噪声可调
delay = 5000;    % 时延可调
seed = 1001203;

a = struct();
a.dopplerHz = 50;              % 多普勒可调
a.enableDopplerComp = true;
a.enableLMS = true;
a.enableViterbi = false;
a.symbolDurationMs = 20;         % 每个符号 20ms
a.guardIntervalMs = 30;          % 保护间隔 30ms
a.dopplerCompRange = -50:10:50;
a.lmsMu = 0.001;
a.lmsFilterLen = 32;

result = fhss_4fsk_simulate(g, fs, snrDb, delay, seed, true, a);
fprintf('BER=%.4f, SER=%.4f\n', result.ber, result.ser);
```

## 4. 当前链路能力

统一函数覆盖以下能力：
1. FHSS + 4FSK 基线链路
2. 时延多径干扰（delay）
3. 多普勒频移注入（dopplerHz）
4. AWGN 白噪声（snrDb）
5. 多普勒补偿扫描（enableDopplerComp）
6. LMS 均衡（enableLMS）
7. 卷积编码 + Viterbi 解码（enableViterbi）

## 5. 指标分离原则（已实现）

为了避免评估混淆，项目已拆分为：
1. BER/SER 单独测试：experiment_ber_ser.m
2. 同步成功率单独测试：experiment_sync_success.m

两者共用同一环境配置文件 FH_env_config.m，因此可复用：
- 白噪声（snrDb）
- 时延（delay）
- 多普勒（dopplerHz）

但统计指标彼此独立，不在同一脚本里混算。

## 6. 说明

为避免功能重复与维护成本，原本拆分的多个演示/对比脚本与重复仿真函数已删除，统一到单入口配置式调用。
