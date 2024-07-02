clc;
clear;
close all;
%% Initial for transmitter
% Number of transmit antenna
Nt = 5; 
% Transmit power 
P_dB = -10:2.5:20;            %in dBm scale
p_dB = db2pow(P_dB); % in linear scale (W) 
% Bandwidth
% BW = 1e9;                             % Bandwidth = 1 GHz
% Initial AWGN antenna noise and processing noise
% Sigma_a = -174 + 10*log10(BW);        % Antenna noise power in dBm
sigma_a = 1e-7;     % Antenna noise power in linear scale
% Sigma_p = - 70 ;                     % Processing noise power in dBm
sigma_p = 1e-5;     % Processing noise power in linear scale      
%% Initial for Energy Harvesting circuit
rho = 0.3;  % The power splitting ratio 
eta = 0.7;  % The energy harvesting efficiency
%% Threshold
tau_r = 2;  % Duration of harvest phase tau_r = T/time_of_harvest
tau_c = 4;  % Duration of source forwarding phase 
tau_e = 4;  % Duration of sensing forwarding phase 
R_r = 1; R_c = 1; R_e = 1; % Target rate for both relay and MD, bit/s/Hz
gammar_th = (2^(tau_r*R_r))-1;  % SNR threshold at R
gammac_th = (2^(tau_c*R_c))-1;  % SNR threshold at R
gammae_th = (2^(tau_r*R_e))-1;  % SNR threshold at R
%% Channel
% Distance: No direct link between BS and MD
dsr = 3;
drm = 7;
drt = 7;
% Pathloss exponent factor 
epsilon = 4;
% Pathloss coefficient
L = 1e-3; % average signal power attenuation at reference distance (d_ref = 1)
pl_r = L*(dsr^-epsilon);  % average channel gain of S-R    (also be the Rayleigh scale parameter) 
pl_m = L*(dsr^-epsilon);  % average channel gain of R-M    (also be the Rayleigh scale parameter) 
% pl_r = L*(dsr^-epsilon);  % average channel gain of R-T  

%%% Signal received at R_X: y_r = ctranspose(h_r)* w *s + noise

% Number of channel realization 
iteration = 1e5;
%% MRT-beamforming
% Initial complex Rayleigh channel at each iteration
for i = 1:iteration
    channel_h = random('Ray',sqrt(pl_r/2), [Nt,1]).*exp(1i*2*pi*rand(Nt,1));
    % MRT beamforming weight 
    weight = channel_h/norm(channel_h);
    Channel(i) = ctranspose(channel_h)*weight;   % element of channel array is scalar = h^H*w
end 
% Simulation
for idx = 1:length(p_dB)
    snr = 2*(1-rho)*p_dB(idx)*(abs(Channel).^2) /((1-rho)*sigma_a + sigma_p);  % Not omit the antenna noise
    snr_omit = 2*(1-rho)*p_dB(idx)*(abs(Channel).^2) /sigma_p;    % Omit the antenna noise
    OP_sim(idx) = sum(snr < gammar_th )/iteration;
    OP_sim_omit(idx) = sum(snr_omit < gammar_th )/iteration;
end
% Theory
for idx = 1:length(p_dB)
    OP_theory(idx) =  1 - igamma(Nt, ((1-rho)*sigma_a + sigma_p)*gammar_th/(2*(1-rho)*p_dB(idx)*pl_r))/gamma(Nt);         % Not omit the antenna noise
    OP_theory_omit(idx) =  1 - igamma(Nt, sigma_p * gammar_th/(2*(1-rho)*p_dB(idx)*pl_r))/gamma(Nt);                        % Omit the antenna noise
end 

%% Compare Results:
figure(1)
hold on; grid on;
semilogy(P_dB,OP_sim,'rd', 'LineWidth',2); 
semilogy(P_dB,OP_theory,'k-+', 'LineWidth',2);
semilogy(P_dB,OP_sim_omit,'y*', 'LineWidth',2);
semilogy(P_dB,OP_theory,'gs', 'LineWidth',2);

legend('Simulation with not omit','Theory with not omit','Simulation with omit','Theory with omit' );

xlabel('SNR in dB');
ylabel('Outage Probability')
xlim([-10 10]);
ylim([1e-5 1])

set(gca, 'FontSize', 12);
set(gca, 'GridLineStyle', '--');
set(gcf, 'Color', 'w'); 
