clear all
close all
clc

%% Header

%       Filename:       GoldCoin_Case_II_Quadrupoles_2D_2Layer_Adiabatic_Resistance.m
%       Author:         Daniel Ellis and Matt Goodson
%       Institution:    BYU Department of Mechanical Engineering - TEMP Lab
%       Date Created:   5/30/2020
%       Last Modified:  12/3/2020
%       Description:    Determines theoretical phase delay curve of two
%                       layers under the 2D assumption using quadrupoles
%                       method. Assumes adiabatic conditions on top and
%                       bottom surface, other than input heat source.
%                       Assumed thermal resistance.
%       Notes:          All units in typical metric convention.
%       Update:         December, Matt added the thermal diffusion length
%                       to see what frequencies the probe will sense the
%                       pump. Also fixed the phase delay plot to go past
%                       -180 to see the trend.

%% 2-layer, 2-D gaussian laser beam heating

%%% --- SETUP --- %%%

format long

% Thermal Reistance values
% --- % Switching to 1 thermal resistance value. Previously, was changed,
% --- % we will keep it constant.
h_Cond = 50000;
R_th = 1 ./ h_Cond;

% Radial distance from pump centerline to probe centerline
% --- % Will be changed to multiple values.
r_probe = 5e-6:5e-6:700e-6; %distance between centers of core in dual probe

% Range of frequencies of interest, expressed in Hertz and radians per
% second
% --- % We changed this from 1e3 to 1e5. Set to 1000.
freq_range = 1000;
omega_range = 2 .* pi .* freq_range;

% Material thermal properties of each layer (1 - gold / 2 - bulk coin)
% Properties from Sam Hayden's paper (find link or where I took this from?)
% --- % k_1 is top layer (RhB), k_2 is lower layer
k_1 = 150; %W/mK
k_2 = 66;  %W/mK

rho_1 = 19300; %kg/m3
rho_2 = 8516; %kg/m3

cp_1 = 128; %J/kgK
cp_2 = 410; %J/kgK

alpha_1 = k_1 ./ (rho_1 .* cp_1);
alpha_2 = k_2 ./ (rho_2 .* cp_2);

% Geometrical properties of all layers
L_1 = 2.5 .* 10^-6; %m
L_2 = 2000 .* 10^-6;  %m

% --- % commented out.
%mu_gold = sqrt(alpha_1./(pi.*freq_range))*1000; %mm
%mu_coin = sqrt(alpha_2./(pi.*freq_range))*1000; %mm
% cutoff_y = 0.500*ones(size(freq_range)); %mm
% 
% figure(5)
% semilogx(freq_range,mu_gold)
% hold on
% semilogx(freq_range,mu_coin)
% semilogx(freq_range,cutoff_y)
% hold off
% legend('gold','coin','probe distance')
% xlabel('frequency')
% ylabel('mu(mm)')
% --- % end comment out

%%

% Pump beam properties (What are the units??)
rad_pump = 1e-4; %m
% --- % find the real value of the wattage using the power meter.
pow_pump = 78e-3; %W

% Imaginary number convention set
j = sqrt(-1);

% Trapz function variable
u = 1:10:1000000;

% --- % Could be power. Need to change !!!
P_2 = .1;

% --- % Turn into a for loop with updated r_probe values.
for ii = 1:length(r_probe)
    %%% --- FUNCTION DEFINITION --- %%%
    ru = @(u) u*r_probe(ii);
    Jo = @(u) besselj(0, ru(u));
    sigma_1 = @(j, omega, alpha_1, u) sqrt(u.^2 + j .* omega ./ alpha_1);
    sigma_2 = @(j, omega, alpha_2, u) sqrt(u.^2 + j .* omega ./ alpha_2);
    V_2 = @(P_2, u, rad_pump) 1 ...
        .* -P_2 .* exp(-(u .* rad_pump).^2 ./ 8) ./ 2 ./ pi;
    Z = @(k_1, k_2, j, omega, alpha_1, alpha_2, L_1, L_2, R_th, u) (-V_2(P_2, u, rad_pump)) ...
        .* (1 ...
        + k_2 .* sigma_2(j, omega, alpha_2, u) .* tanh(sigma_2(j, omega, alpha_2, u) .* L_2) .* R_th ...
        + k_2 ./ k_1 .* sigma_2(j, omega, alpha_2, u) ./ sigma_1(j, omega, alpha_1, u) .* tanh(sigma_2(j, omega, alpha_2, u) .* L_2) .* tanh(sigma_1(j, omega, alpha_1, u) .* L_1)) ...
        ./ (k_1 .* sigma_1(j, omega, alpha_1, u) .* tanh(sigma_1(j, omega, alpha_1, u) .* L_1) ...
        + k_2 .* sigma_2(j, omega, alpha_2, u) .* tanh(sigma_2(j, omega, alpha_2, u) .* L_2) .* k_1 .* sigma_1(j, omega, alpha_1, u) .* tanh(sigma_1(j, omega, alpha_1, u) .* L_1) .* R_th ...
        + k_2 .* sigma_2(j, omega, alpha_2, u) .* tanh(sigma_2(j, omega, alpha_2, u) .* L_2));
    Temp_top_to_integrate = @(pow_pump, u, k_1, k_2, j, omega, alpha_1, alpha_2, L_1, L_2, rad_pump, R_th) 1 ...
        .* u ...
        .* Jo(u) ...
        .* Z(k_1, k_2, j, omega, alpha_1, alpha_2, L_1, L_2, R_th, u);

    %%% --- CALCULATION --- %%%

    for num_res = 1:length(R_th)
        % set to false
        d_value = 0;
        p_value = 0;
        for num_freq = 1:length(omega_range)
    % include offset here (with 
            Temp_top(num_freq) = trapz(u, Temp_top_to_integrate(pow_pump, u, k_1, k_2, j, omega_range(num_freq), alpha_1, alpha_2, L_1, L_2, rad_pump, R_th(num_res)));
            value(num_freq) = rad2deg(angle(Temp_top(num_freq)));

            % ------ COMMENT OUT IF YOU WANT NO ALTERATIONS -------- %
            if num_freq > 1
            d_value = abs(value(num_freq)-value(num_freq-1));
            end
            if p_value < -695
                value(num_freq) = rad2deg(angle(Temp_top(num_freq))) - 720;
            elseif rad2deg(angle(Temp_top(num_freq))) > 0 && p_value < -400
                value(num_freq) = rad2deg(angle(Temp_top(num_freq))) - 720;
            elseif rad2deg(angle(Temp_top(num_freq))) > 0
                value(num_freq) = rad2deg(angle(Temp_top(num_freq))) - 360;
            elseif d_value > 200
                value(num_freq) = rad2deg(angle(Temp_top(num_freq))) - 360;
            else
                value(num_freq) = value(num_freq);
            end
            % ---------- TO HERE ----------%
            phase_delay{num_res}(num_freq) = value(num_freq);
            p_value = value(num_freq);
        end
    end

    for i = 1:length(R_th)

        data2plot{i}(1, :) = freq_range;
        data2plot{i}(2, :) = phase_delay{i};

    end
    %%
    figure(1)
    plot(r_probe(ii), phase_delay{1}, '-^', 'Color', [0 1 0], 'LineWidth', 1.25, 'MarkerEdgeColor', [0 1 0], 'MarkerFaceColor', [0 1 0], 'MarkerSize', 6)
    hold on
    xlim([0 800e-6])
end
% semilogx(freq_range, phase_delay{2}, '-o', 'Color', [0 0.88 0], 'LineWidth', 1.25, 'MarkerEdgeColor', [0 0.88 0], 'MarkerFaceColor', [0 0.88 0], 'MarkerSize', 6)
% semilogx(freq_range, phase_delay{3}, '-p', 'Color', [0 0.76 0], 'LineWidth', 1.25, 'MarkerEdgeColor', [0 0.76 0], 'MarkerFaceColor', [0 0.76 0], 'MarkerSize', 6)
% semilogx(freq_range, phase_delay{4}, '-h', 'Color', [0 0.64 0], 'LineWidth', 1.25, 'MarkerEdgeColor', [0 0.64 0], 'MarkerFaceColor', [0 0.64 0], 'MarkerSize', 6)
% semilogx(freq_range, phase_delay{5}, '-s', 'Color', [0 0.52 0], 'LineWidth', 1.25, 'MarkerEdgeColor', [0 0.52 0], 'MarkerFaceColor', [0 0.52 0], 'MarkerSize', 6)
% semilogx(freq_range, phase_delay{6}, '-d', 'Color', [0 0.4 0], 'LineWidth', 1.25, 'MarkerEdgeColor', [0 0.4 0], 'MarkerFaceColor', [0 0.4 0], 'MarkerSize', 6)
% % semilogx(freq_range, phase_delay{7})
% % semilogx(freq_range, phase_delay{8})
% % semilogx(freq_range, phase_delay{9})
hold off

% % % %%
% % % %%% --- PLOTTING --- %%%
% % % 
% % % [Frequency{1}, Delay{1}] = textread('Case_II_1000h_Phase.txt', '%f %f', 'headerlines', 0);
% % % [Frequency{2}, Delay{2}] = textread('Case_II_2187h_Phase.txt', '%f %f', 'headerlines', 0);
% % % [Frequency{3}, Delay{3}] = textread('Case_II_4782h_Phase.txt', '%f %f', 'headerlines', 0);
% % % [Frequency{4}, Delay{4}] = textread('Case_II_10456h_Phase.txt', '%f %f', 'headerlines', 0);
% % % [Frequency{5}, Delay{5}] = textread('Case_II_22865h_Phase.txt', '%f %f', 'headerlines', 0);
% % % [Frequency{6}, Delay{6}] = textread('Case_II_50000h_Phase.txt', '%f %f', 'headerlines', 0);
% % % [Frequency{7}, Delay{7}] = textread('H13_FLAT_1000h_Phase.txt', '%f %f', 'headerlines', 0);
% % % [Frequency{8}, Delay{8}] = textread('H13_FLAT_2187h_Phase.txt', '%f %f', 'headerlines', 0);
% % % [Frequency{9}, Delay{9}] = textread('H13_FLAT_4782h_Phase.txt', '%f %f', 'headerlines', 0);
% % % [Frequency{10}, Delay{10}] = textread('H13_FLAT_10456h_Phase.txt', '%f %f', 'headerlines', 0);
% % % [Frequency{11}, Delay{11}] = textread('H13_FLAT_22865h_Phase.txt', '%f %f', 'headerlines', 0);
% % % [Frequency{12}, Delay{12}] = textread('H13_FLAT_50000h_Phase.txt', '%f %f', 'headerlines', 0);
% % % [Frequency{13}, Delay{13}] = textread('Case_II_Limited_1000h_Phase.txt', '%f %f', 'headerlines', 0);
% % % [Frequency{14}, Delay{14}] = textread('Case_II_Limited_2187h_Phase.txt', '%f %f', 'headerlines', 0);
% % % [Frequency{15}, Delay{15}] = textread('Case_II_Limited_4782h_Phase.txt', '%f %f', 'headerlines', 0);
% % % [Frequency{16}, Delay{16}] = textread('Case_II_Limited_10456h_Phase.txt', '%f %f', 'headerlines', 0);
% % % [Frequency{17}, Delay{17}] = textread('Case_II_Limited_22865h_Phase.txt', '%f %f', 'headerlines', 0);
% % % [Frequency{18}, Delay{18}] = textread('Case_II_Limited_50000h_Phase.txt', '%f %f', 'headerlines', 0);
% % % 
% % % for i = 1:length(R_th)
% % %     
% % %     data2plot{i}(1, :) = freq_range;
% % %     data2plot{i}(2, :) = phase_delay{i};
% % %     
% % % end
% % % 
% % % fileID = fopen('Case_II_Phase.txt', 'w');
% % % 
% % % for i = 1:length(R_th)
% % %     fprintf(fileID, '%f %f\n', data2plot{i});
% % %     fprintf(fileID, '%f %f\n', [0, 0]);
% % % end
% % % fclose(fileID);
% % % 
% % % fig1 = figure(1);
% % % %fig1.Position = ([404 390 560 420])
% % % fig1.Position = ([154 390 1080 420])
% % % 
% % % semilogx(freq_range, phase_delay{1}, '-^', 'Color', [0 1 0], 'LineWidth', 1.25, 'MarkerEdgeColor', [0 1 0], 'MarkerFaceColor', [0 1 0], 'MarkerSize', 6)
% % % hold on
% % % semilogx(freq_range, phase_delay{2}, '-o', 'Color', [0 0.88 0], 'LineWidth', 1.25, 'MarkerEdgeColor', [0 0.88 0], 'MarkerFaceColor', [0 0.88 0], 'MarkerSize', 6)
% % % semilogx(freq_range, phase_delay{3}, '-p', 'Color', [0 0.76 0], 'LineWidth', 1.25, 'MarkerEdgeColor', [0 0.76 0], 'MarkerFaceColor', [0 0.76 0], 'MarkerSize', 6)
% % % semilogx(freq_range, phase_delay{4}, '-h', 'Color', [0 0.64 0], 'LineWidth', 1.25, 'MarkerEdgeColor', [0 0.64 0], 'MarkerFaceColor', [0 0.64 0], 'MarkerSize', 6)
% % % semilogx(freq_range, phase_delay{5}, '-s', 'Color', [0 0.52 0], 'LineWidth', 1.25, 'MarkerEdgeColor', [0 0.52 0], 'MarkerFaceColor', [0 0.52 0], 'MarkerSize', 6)
% % % semilogx(freq_range, phase_delay{6}, '-d', 'Color', [0 0.4 0], 'LineWidth', 1.25, 'MarkerEdgeColor', [0 0.4 0], 'MarkerFaceColor', [0 0.4 0], 'MarkerSize', 6)
% % % 
% % % semilogx(Frequency{1}, Delay{1}, '--^', 'Color', [0 0.4 0.4], 'LineWidth', 1.25, 'MarkerEdgeColor', [0 0.4 0.4], 'MarkerSize', 6)
% % % semilogx(Frequency{2}, Delay{2}, '--o', 'Color', [0 0.52 0.52], 'LineWidth', 1.25, 'MarkerEdgeColor', [0 0.52 0.52], 'MarkerSize', 6)
% % % semilogx(Frequency{3}, Delay{3}, '--p', 'Color', [0 0.64 0.64], 'LineWidth', 1.25, 'MarkerEdgeColor', [0 0.64 0.64], 'MarkerSize', 6)
% % % semilogx(Frequency{4}, Delay{4}, '--h', 'Color', [0 0.76 0.76], 'LineWidth', 1.25, 'MarkerEdgeColor', [0 0.76 0.76], 'MarkerSize', 6)
% % % semilogx(Frequency{5}, Delay{5}, '--s', 'Color', [0 0.88 0.88], 'LineWidth', 1.25, 'MarkerEdgeColor', [0 0.88 0.88], 'MarkerSize', 6)
% % % semilogx(Frequency{6}, Delay{6}, '--d', 'Color', [0 1 1], 'LineWidth', 1.25, 'MarkerEdgeColor', [0 1 1], 'MarkerSize', 6)
% % % 
% % % semilogx(Frequency{13}, Delay{13}, '-.^', 'Color', [1 0.6 0], 'LineWidth', 1.25, 'MarkerEdgeColor', [1 0.6 0], 'MarkerFaceColor', [1 0.6 0], 'MarkerSize', 6)
% % % semilogx(Frequency{14}, Delay{14}, '-.o', 'Color', [0.88 0.48 0], 'LineWidth', 1.25, 'MarkerEdgeColor', [0.88 0.48 0], 'MarkerFaceColor', [0.88 0.48 0], 'MarkerSize', 6)
% % % semilogx(Frequency{15}, Delay{15}, '-.p', 'Color', [0.76 0.36 0], 'LineWidth', 1.25, 'MarkerEdgeColor', [0.76 0.36 0], 'MarkerFaceColor', [0.76 0.36 0], 'MarkerSize', 6)
% % % semilogx(Frequency{16}, Delay{16}, '-.h', 'Color', [0.64 0.24 0], 'LineWidth', 1.25, 'MarkerEdgeColor', [0.64 0.24 0], 'MarkerFaceColor', [0.64 0.24 0], 'MarkerSize', 6)
% % % semilogx(Frequency{17}, Delay{17}, '-.s', 'Color', [0.52 0.12 0], 'LineWidth', 1.25, 'MarkerEdgeColor', [0.52 0.12 0], 'MarkerFaceColor', [0.52 0.12 0], 'MarkerSize', 6)
% % % semilogx(Frequency{18}, Delay{18}, '-.d', 'Color', [0.4 0 0], 'LineWidth', 1.25, 'MarkerEdgeColor', [0.4 0 0], 'MarkerFaceColor', [0.4 0 0], 'MarkerSize', 6)
% % % 
% % % semilogx(Frequency{7}, Delay{7}, ':^', 'Color', [0.4 0 0.4], 'LineWidth', 1.25, 'MarkerEdgeColor', [0.4 0 0.4], 'MarkerSize', 6)
% % % semilogx(Frequency{8}, Delay{8}, ':o', 'Color', [0.52 0 0.52], 'LineWidth', 1.25, 'MarkerEdgeColor', [0.52 0 0.52], 'MarkerSize', 6)
% % % semilogx(Frequency{9}, Delay{9}, ':p', 'Color', [0.64 0 0.64], 'LineWidth', 1.25, 'MarkerEdgeColor', [0.64 0 0.64], 'MarkerSize', 6)
% % % semilogx(Frequency{10}, Delay{10}, ':h', 'Color', [0.76 0 0.76], 'LineWidth', 1.25, 'MarkerEdgeColor', [0.76 0 0.76], 'MarkerSize', 6)
% % % semilogx(Frequency{11}, Delay{11}, ':s', 'Color', [0.88 0 0.88], 'LineWidth', 1.25, 'MarkerEdgeColor', [0.8 0 0.88], 'MarkerSize', 6)
% % % semilogx(Frequency{12}, Delay{12}, ':d', 'Color', [1 0 1], 'LineWidth', 1.25, 'MarkerEdgeColor', [1 0 1], 'MarkerSize', 6)
% % % 
% % % xlim([0.1 100])
% % % xlabel('Frequency (Hz)')
% % % ylabel('Phase Delay (^o)')
% % % leg = legend('Case I Analytical - 1000 W/m^2K', '2187 W/m^2K', '4782 W/m^2K', '10456 W/m^2K', '22865 W/m^2K', '50000 W/m^2K', ...
% % %     'Case I Numerical - 1000 W/m^2K', '2187 W/m^2K', '4782 W/m^2K', '10456 W/m^2K', '22865 W/m^2K', '50000 W/m^2K', ...
% % %     'Case I Analytical Bounded - 1000 W/m^2K', '2187 W/m^2K', '4782 W/m^2K', '10456 W/m^2K', '22865 W/m^2K', '50000 W/m^2K', ...
% % %     'Benchmark I - 1000 W/m^2K', '2187 W/m^2K', '4782 W/m^2K', '10456 W/m^2K', '22865 W/m^2K', '50000 W/m^2K');
% % % title('Case II')
% % % 
% % % leg.Location = 'eastoutside';
% % % leg.NumColumns = 2;
% % % 
% % % 

%% END OF CODE