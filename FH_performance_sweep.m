clc;
clear;
close all;

g = 40;
fs = 100000;
delay = 0;
snrVec = -20:2:0;

berVec = zeros(size(snrVec));
serVec = zeros(size(snrVec));

for k = 1:numel(snrVec)
    result = fhss_4fsk_simulate(g, fs, snrVec(k), delay);
    berVec(k) = result.ber;
    serVec(k) = result.ser;
end

figure;
semilogy(snrVec, berVec, 'o-', 'LineWidth', 1.5);
hold on;
semilogy(snrVec, serVec, 's-', 'LineWidth', 1.5);
grid on;
xlabel('SNR (dB)');
ylabel('Error Rate');
title('FH-4FSK BER / SER Performance');
legend('BER', 'SER', 'Location', 'southwest');
hold off;

disp(table(snrVec(:), berVec(:), serVec(:), 'VariableNames', {'SNR_dB', 'BER', 'SER'}));