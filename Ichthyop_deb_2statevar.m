%--------------------------------------------------------------------------
% DEB model implemented in Ichthyop
% Numerical integration : Euler
% Author                : Laure Pecquerie
% Modified              : J. Flores
% 2020/07/20 - 
%--------------------------------------------------------------------------

%% Initialization - time step, simulation duration, vector length

dt     = 0.0833;                        % d, time step of the model = 2h ==> dt = 2/24h
t_0    = 0;                             % d, January 1st
t_end  = 4*365 + t_0 - 1;               % d, last day of the simulation
n_iter = ceil((t_end - t_0 + 1) / dt);  % number of integration loop iterations

%% Forcing variables

temp  = 10 : 1 : 30;   % Temperaturas en C� para testear
f_res = 0.1 : 0.1 : 1; % Functional response to test

%X = repmat(20000, n_iter, 1); % J/l , Food density (here in Joules per liter of water but can be different depending on the study)
% We assume abundant food / ad libitum for now

% Primary parameters
T_ref = 16 + 273;      % K, Reference temperature (not to be changed) [Pethybridge et al 2013]
T_A   = 9800;          % K, Arrhenius temperature [Pethybridge et al 2013]

% T_L   = 10 + 273.15; % K, Lower boundary of the thermal range
% T_H   = 30 + 273.15; % K, Upper boundary of the thermal range
% T_AL  = 3000;        % K, Arrhenius temperature at the lower boundary
% T_AH  = 32000;       % K, Arrhenius temperature at the upper boundary

% if T_L > T_ref || T_H < T_ref
%      fprintf('Warning from temp_corr: invalid parameter combination, T_L > T_ref and/or T_H < T_ref\n')
% end

% K Half saturation constant: necesario para "f" y la estacionalidad
kap_X = 0.71;         % -, digestion efficiency of food to reserve [Pethybridge et al 2013]
p_Xm  = 325;          % J.cm-2.d-1 , Surface-area-specific maximum ingestion rate [Pethybridge et al 2013] Cambia con el tipo de alimento
p_Am  = kap_X * p_Xm; % 325 * 0.71 = 230.75 ;J.cm-2.d-1 , Surface-area-specific maximum assimilation rate [Pethybridge et al 2013]
E_m   = 2700;         % J.cm^(-3), maximum reserve density [Pethybridge et al 2013]
v     = p_Am / E_m;   % 230.75/2700=0.0855; cm/d' , energy conductance --modif-- [Pethybridge et al 2013]
E_G   = 4000;         % J/cm^3, spec cost for structure [Pethybridge et al 2013] lo que hay que pagar para generar 1 cm3 de estructura
p_M   = 48;           % J/d.cm^3' , vol-spec somatic maintenance rate [Pethybridge et al 2013]
kap   = 0.7;          % - , allocation fraction to soma [Pethybridge et al 2013] Para mantenimiento y crecimiento
kap_R = 0.95;         % - , reproduction efficiency [Pethybridge et al 2013]

L_wb  = 0.25;          % cm, total length at mouth opening --> ?? total or fork length? [add my pet]
L_wp  = 9.077;        % cm, total length at puberty --> ?? guess [add my pet]

% auxiliary parameters
del_M_t = 0.154; % - , shape coefficient (Total Length)[Pethybridge et al 2013]
del_M_s = 0.166; % - , Este valor produce una talla de 1.51 cm menos que la talla total, que es lo observado en figuras de ictiometro

length = 0; % 1 = Total Length | 0 = Standard Length
if length == 1
    del_M = del_M_t;
    mkdir('DEB_out_t');
    subdir = 'DEB_out_t';
else
    del_M = del_M_s;
    mkdir('DEB_out_s');
    subdir = 'DEB_out_s';
end

% compound parameters
V_b = (L_wb * del_M)^3; % cm^3, structural volume at birth (first feeding)
V_p = (L_wp * del_M)^3; % cm^3, structural volume at puberty

%% Initial conditions for the state variables = egg stage

E_0  = 1;                  % J, egg content
V_0  = (0.0025 * del_M)^3; % cm, structural volume --> !! try different values % valor inicial de ichthyop (quiza mal)
E_R0 = 0;                  % J, reproduction buffer

%-------------------------------------------------------------------------%
%% Numerical integration - Euler method

t      = zeros(n_iter,1);
E      = zeros(n_iter,1);
V      = zeros(n_iter,1);
E_R    = zeros(n_iter,1);
F      = zeros(n_iter,1);

t(1)   = t_0;    % d,    Time vector initialization 
E(1)   = E_0;    % J,    Initial reserve
V(1)   = V_0;    % cm^3, Initial structure
E_R(1) = E_R0;   % J,    Reproduction buffer   ------ I put an indice to try to run the script

for j = 1:size(temp,2)
    
    for k = 1:size(f_res,2)
        
        T = repmat(temp(j) + 273.15, n_iter,1); % K, Temperature
        f = f_res(k);
        
        for i = 1:n_iter-1

        % Temperature correction ---> should be cke!
        %s_A = exp(T_A/ T_ref - T_A ./ T(i));  % Arrhenius factor
        %s_L_ratio = (1 + exp(T_AL/ T_ref - T_AL/ T_L)) ./ ...
        %            (1 + exp(T_AL ./ T(i)   - T_AL/ T_L));
        %s_H_ratio = (1 + exp(T_AH/ T_H - T_AH/ T_ref)) ./ ...
        %            (1 + exp(T_AH/ T_H - T_AH ./ T(i)  ));
        %c_T = s_A .* ((T(i) <= T_ref) .* s_L_ratio + (T(i) > T_ref) .* s_H_ratio); 
 
        c_T   = exp(T_A/ T_ref - T_A ./ T(i));  % simple Arrhenius correction factor
        p_AmT = c_T * p_Am;
        vT    = c_T * v;
        p_MT  = c_T * p_M;
 
        % Scaled functional response
        % f = X(i) / (X(i) + K); % -, scaled functional response
        % f = 0.9999;

        % Fluxes , j/d
        if V(i) < V_b 
            p_A_flux = 0;
        else
            p_A_flux = f * p_AmT * V(i).^(2/3); % J/d assimilation rate 
        end

        p_M_flux = p_MT * V(i); % J/d , Volume-related somatic maintenance
        p_C_flux = E(i) .* ( E_G * p_AmT / E_m .* V(i)^(-1/3) + p_MT) ./ ( kap .* E(i) ./ V(i) + E_G); % utilization rate
        p_G_flux = kap * p_C_flux - p_M_flux;% J/d growth
        p_J_flux = (1- kap) / kap * p_MT * min(V(i), V_p)  ; % J/d, Maturity maintenance !! fichier word erreur? il manque le min (V, V_p) et [p_M]

        if or( (p_G_flux < 0), ((1 - kap) * p_C_flux - p_J_flux <0))
            disp('starvation')
            return
        else
            dE = p_A_flux - p_C_flux ; % J/d, 
            dV = p_G_flux / E_G;       % cm^3/d,
            if V(i) < V_p
                dE_R = 0;              % J/d, No reproduction buffer
            else  
                dE_R = (1 - kap) * p_C_flux - p_J_flux; % J/d, energy allocated to reproduction
            end 
        end

        E(i+1)   = E(i) + dE * dt ;     % J/d, Energy available into reserve
        V(i+1)   = V(i) + dV * dt ;     % cm^3, Volume of the structure
        E_R(i+1) = E_R(i) + dE_R * dt ; % J/d, Energy invested to reproduction

%     % Spawning rule 1: Every 30 days
%     if (i/360 - round(i/360) == 0)
%         E_R(i+1) = 0; % El E_R regresa a cero
%     end
               
%     % Spawning rule 2: One spawning peak in September
%     if (i == 3240 || i == 7560 || i == 11880 || i == 16200) % iterator indices for the September months
%         E_R(i+1) = E_R(i) % El E_R regresa a cero
%     end

%         % Spawning rule 2:  One spawning peak in September
%         % spaw_index = [3240 7560 11880];
%         if (i+1 == 3240 || i+1 == 7560 || i+1 == 11880 || i+1 == 16200) % iterator indices for the September months (el desove se hace entre i y i+1)
%             F(i+1)   = E_R(i+1) * kap_R / E_0;
%             E_R(i+1) = 0;
%         end

        % Spawning rule 3: Two spawning peaks in September & March
        % spaw_index = [3240 7560 11880];
        if (i+1 == 3240 || i+1 == 7560 || i+1 == 11880 || i+1 == 16200 || ... % iterator indices for the September months (el desove se hace entre i y i+1)
            i+1 == 1080 || i+1 == 5400 || i+1 == 9720  || i+1 == 14040)       % iterator indices for the March months
            F(i+1)   = E_R(i+1) * kap_R / E_0;
            E_R(i+1) = 0;
        end
        
        t(i+1)   = t(i) + dt ;
        
        t_vec = repmat(temp(j), n_iter,1);  % C, Temperature
        f_vec = repmat(f_res(k), n_iter,1); % f, Functional response
        
        end
        
        %% Observable variables
    
        % Physical length
        L_w = (V.^(1/3))./del_M ; % cm, Physical length

        % Wet weight
        d_V  = 0.23;   % g/cm^3, specific density of structure (dry weight)
        mu_V = 500000; % J/mol, specific chemical potential of structure
        mu_E = 550000; % J/mol, specific chemical potential of reserve
        w_V  = 23.9;   % g/mol, molecular weight of structure
        w_E  = 23.9;   % g/mol, molecular weight of reserve
        c_w  = 0.756;  % (c_w * W_w = total water weight)

        W_V        = d_V.*V./(1 - c_w);
        W_E        = (w_E/mu_E).*E./(1 - c_w);
        W_ER       = (w_E/mu_E).*E_R./(1 - c_w);
        
        out_mat = table(t,E,V,E_R,W_V,W_E,W_ER,L_w,F,t_vec,f_vec,...
                        'VariableNames',...
                        {'t','E','V','E_R','W_E','W_V','W_ER','L_w','F','temp','f'});
        writetable(out_mat, strcat(subdir, '/DEB_out','T',num2str(temp(j)),'f',num2str(f_res(k)),'.txt'))
    end
end
