% FH-4FSK 演示入口，复用公共仿真函数
clc;
clear;
close all;

g = 40;
fs = 100000;
r = 10000;
delay = 0;
seed = 1001203;

result = fhss_4fsk_simulate(g, fs, r, delay, seed, true);
disp(["BER=" + string(result.ber), "SER=" + string(result.ser)]);

