function SR830_data_acquisition
clc; clear;

current_source=0;   % if using current source, set it larger than 1, set it to 0 for voltage source
plot_delta_t=0.1;

reference_x=10;
reference_y=500;

if (current_source)
    
    reference_y2=reference_y+170;
    %%%%%%%%%%%%%%%%%%%%%%%%%%%current source
    ke6221=instrfind('Type', 'visa-serial', 'RsrcName', 'ASRL3::INSTR');
    if(isempty(ke6221))
        ke6221=  visa('agilent', 'ASRL3::INSTR'); % create the connection
    else
        fclose(ke6221);
    end
    fopen(ke6221);

    uicontrol('Style', 'text', 'String', 'Current Setting(P2P)', 'Position', [reference_x reference_y2 100 18]);
    uicontrol('Style', 'text', 'String', 'AMP', 'Position', [reference_x reference_y2-25 25 18]);
    hcurrent=uicontrol('Style', 'edit', 'String', '1e-6', 'Position', [reference_x+30 reference_y2-25 50 18]);
    uicontrol('Style', 'text', 'String', 'A', 'Position', [reference_x+85 reference_y2-25 15 18]);

    uicontrol('Style', 'text', 'String', 'FRE', 'Position', [reference_x reference_y2-45 25 18]);
    hfrequency=uicontrol('Style', 'edit', 'String', '1', 'Position', [reference_x+30 reference_y2-45 50 18]);
    uicontrol('Style', 'text', 'String', 'Hz', 'Position', [reference_x+85 reference_y2-45 15 18]);

    h_current_run=uicontrol('Style', 'pushbutton', 'String', 'RUN', 'Position', [reference_x reference_y2-80 35 30], 'Callback', {@current_activate, hcurrent, hfrequency, ke6221});
    uicontrol('Style', 'pushbutton', 'String', 'STOP', 'Position', [reference_x+40 reference_y2-80 35 30], 'Callback', {@current_stop, ke6221, h_current_run});
end

lock_in830= instrfind('Type', 'visa-gpib');
if(isempty(lock_in830))
    lock_in830=visa('ni','GPIB0::8::INSTR');
%     lock_in830=visa('agilent','GPIB0::8::INSTR');
else
    fclose(lock_in830);
end
fopen(lock_in830);
%fprintf(lock_in830, 'OUTX 1 <lf>');

[time_constant, time_constant_unit]=read_time_constant(lock_in830);
[sensitivity_voltage, sensitivity_unit]=read_sensitivity(lock_in830);

fprintf(lock_in830, 'FREQ?');
current_frequency=str2double(fscanf(lock_in830));
current_voltage=0.004; % set the voltage to be minimum to avoid sample burn up
fprintf(lock_in830, 'HARM?');
current_harmonic=str2double(fscanf(lock_in830));

if(current_source)
    fprintf(lock_in830, 'FMOD 0 <lf>'); %FMOD (?) {i} Set (Query) the Reference Source to External (0) or Internal (1).
    fprintf(lock_in830, 'RSLP 1 <lf>'); %RSLP (?) {i} Set (Query) the External Reference Slope to Sine(0), TTL Rising (1), or TTL Falling (2).
else
    fprintf(lock_in830, 'FMOD 1 <lf>'); 
end
fprintf(lock_in830, 'PHAS 0 <lf>'); %sets or queries the reference phase shift


hsub1=subplot(2,1,1);
hsub2=subplot(2,1,2);

uicontrol('Style', 'text', 'String', 'Lock-in Setting', 'Position', [reference_x reference_y+25 80 18]);
uicontrol('Style', 'text', 'String', 'Time constant', 'Position', [reference_x+5 reference_y 70 18]);
htime_constant=uicontrol('Style', 'text', 'String', num2str(time_constant), 'Position', [reference_x+5 reference_y-20 30 18]);
htime_constant_unit=uicontrol('Style', 'text', 'String', time_constant_unit, 'Position', [reference_x+45 reference_y-20 30 18]);
uicontrol('Style', 'pushbutton', 'String', 'UP', 'Position', [reference_x+5 reference_y-52 30 30], 'Callback', {@timeconstantup, htime_constant, htime_constant_unit, lock_in830});
uicontrol('Style', 'pushbutton', 'String', 'DW', 'Position', [reference_x+45 reference_y-52 30 30], 'Callback', {@timeconstantdown, htime_constant, htime_constant_unit, lock_in830});
uicontrol('Style', 'text', 'String', 'Sensitivity', 'Position', [reference_x+5 reference_y-75 70 18]);
hsensitivity=uicontrol('Style', 'text', 'String', num2str(sensitivity_voltage), 'Position', [reference_x+5 reference_y-95 30 18]);
hsensitivity_unit=uicontrol('Style', 'text', 'String', sensitivity_unit, 'Position', [reference_x+45 reference_y-95 30 18]);
uicontrol('Style', 'pushbutton', 'String', 'UP', 'Position', [reference_x+5 reference_y-127 30 30], 'Callback', {@sentivity_voltageup, hsensitivity, hsensitivity_unit, lock_in830});
uicontrol('Style', 'pushbutton', 'String', 'DW', 'Position', [reference_x+45 reference_y-127 30 30], 'Callback', {@sentivity_voltagedown, hsensitivity, hsensitivity_unit, lock_in830});

if(current_source)
    href_frequency=uicontrol('Style', 'text', 'String', num2str(current_frequency), 'Position', [reference_x-5 reference_y-155 40 18]);
else
    href_frequency=uicontrol('Style', 'edit', 'String', num2str(current_frequency), 'Position', [reference_x-5 reference_y-155 40 18]);
    hvoltage=uicontrol('Style', 'edit', 'String', num2str(current_voltage), 'Position', [reference_x-5 reference_y-175 40 18]);
    uicontrol('Style', 'text', 'String', 'V', 'Position', [reference_x+36 reference_y-175 15 18]);
end
uicontrol('Style', 'text', 'String', 'Hz', 'Position', [reference_x+36 reference_y-155 15 18]);
uicontrol('Style', 'text', 'String', 'Harm #', 'Position', [reference_x-5 reference_y-195 40 18]);
hharmonic=uicontrol('Style', 'edit', 'String', num2str(current_harmonic), 'Position', [reference_x+36 reference_y-195 20 18]);
if(current_source)
    uicontrol('Style', 'pushbutton', 'String', 'SET', 'Position', [reference_x+53 reference_y-180 30 30], 'Callback', {@set_harmonic, lock_in830, hharmonic});
else
    uicontrol('Style', 'pushbutton', 'String', 'SET', 'Position', [reference_x+53 reference_y-180 30 30], 'Callback', {@set_voltage, lock_in830, href_frequency, hvoltage, hharmonic});
end

hA=uicontrol('Style', 'radiobutton', 'String', 'A', 'Position', [reference_x-5 reference_y-220 30 18]);
hAB=uicontrol('Style', 'radiobutton', 'String', 'A-B', 'Position', [reference_x+25 reference_y-220 40 18]);
set(hA, 'Callback', {@setA, lock_in830, hAB});
set(hAB, 'Callback', {@setAB, lock_in830, hA});
fprintf(lock_in830, 'ISRC?');
AorAB=str2double(fscanf(lock_in830));
if(abs(AorAB)<1e-10)
    set(hA, 'Value', 1);
else
    set(hAB, 'Value', 1);
end

hAC=uicontrol('Style', 'radiobutton', 'String', 'AC', 'Position', [reference_x-5 reference_y-240 35 18]);
hDC=uicontrol('Style', 'radiobutton', 'String', 'DC', 'Position', [reference_x+30 reference_y-240 35 18]);
set(hAC, 'Callback', {@setAC, lock_in830, hDC});
set(hDC, 'Callback', {@setDC, lock_in830, hAC});
fprintf(lock_in830, 'ICPL?');
ACorDC=str2double(fscanf(lock_in830));
if(abs(ACorDC)<1e-10)
    set(hAC, 'Value', 1);
else
    set(hDC, 'Value', 1);
end
if(current_source)
    htake_data=uicontrol('Style', 'pushbutton', 'String', 'DATA', 'Position', [reference_x-5 reference_y-270 40 25], 'Callback', {@take_data, lock_in830, hsub1, hsub2, current_source,hcurrent, href_frequency, plot_delta_t});
else
    htake_data=uicontrol('Style', 'pushbutton', 'String', 'DATA', 'Position', [reference_x-5 reference_y-270 40 25], 'Callback', {@take_data, lock_in830, hsub1, hsub2, current_source,hvoltage, href_frequency, plot_delta_t});
end
set(htake_data, 'Value', 0, 'UserData', [0,0,0,0]);
uicontrol('Style', 'pushbutton', 'String', 'STOP', 'Position', [reference_x+40 reference_y-270 40 25], 'Callback', {@stop_data, htake_data});

uicontrol('Style', 'text', 'String', 'Center', 'Position', [reference_x-5 reference_y-320 35 18]);
uicontrol('Style', 'text', 'String', 'Scope', 'Position', [reference_x+40 reference_y-320 35 18]);
h_amp_center=uicontrol('Style', 'edit', 'String', '0', 'Position', [reference_x-5 reference_y-340 35 18]);
h_amp_scope=uicontrol('Style', 'edit', 'String', '0', 'Position', [reference_x+40 reference_y-340 35 18]);
uicontrol('Style', 'pushbutton', 'String', 'SET', 'Position', [reference_x-3 reference_y-368 30 25], 'Callback', {@set_amp_center, htake_data,h_amp_center});
uicontrol('Style', 'pushbutton', 'String', 'SET', 'Position', [reference_x+42.5 reference_y-368 30 25], 'Callback', {@set_amp_scope, htake_data,h_amp_scope});
uicontrol('Style', 'pushbutton', 'String', 'Amp Reset', 'Position', [reference_x-5 reference_y-300 80 25], 'Callback', {@clear_amp_change, htake_data,h_amp_center,h_amp_scope});

uicontrol('Style', 'text', 'String', 'Center', 'Position', [reference_x-5 reference_y-417 35 18]);
uicontrol('Style', 'text', 'String', 'Scope', 'Position', [reference_x+40 reference_y-417 35 18]);
h_phase_center=uicontrol('Style', 'edit', 'String', '0', 'Position', [reference_x-5 reference_y-437 35 18]);
h_phase_scope=uicontrol('Style', 'edit', 'String', '0', 'Position', [reference_x+40 reference_y-437 35 18]);
uicontrol('Style', 'pushbutton', 'String', 'SET', 'Position', [reference_x-3 reference_y-463 30 25], 'Callback', {@set_phase_center, htake_data,h_phase_center});
uicontrol('Style', 'pushbutton', 'String', 'SET', 'Position', [reference_x+42.5 reference_y-463 30 25], 'Callback', {@set_phase_scope, htake_data,h_phase_scope});
uicontrol('Style', 'pushbutton', 'String', 'Phase Reset', 'Position', [reference_x-5 reference_y-398 80 25], 'Callback', {@clear_phase_change, htake_data,h_phase_center,h_phase_scope});

if(current_source)
    uicontrol('Style', 'pushbutton', 'String', 'Refresh Lock-in', 'Position', [reference_x-5 reference_y+50 110 25],...
        'Callback', {@Refresh_all_current,lock_in830,htime_constant,htime_constant_unit,hsensitivity,hsensitivity_unit,href_frequency,hharmonic, hA,hAB,hAC,hDC});
else
    uicontrol('Style', 'pushbutton', 'String', 'Refresh Lock-in', 'Position', [reference_x-5 reference_y+50 110 25],...
        'Callback', {@Refresh_all,lock_in830,htime_constant,htime_constant_unit,hsensitivity,hsensitivity_unit,href_frequency,hvoltage,hharmonic, hA,hAB,hAC,hDC});
end

end

function current_activate(hObj,event, hcurrent, hfrequency, ke6221)

line_terminator='';
source_current_ac=str2double(get(hcurrent, 'String'));
source_frequency=str2double(get(hfrequency, 'String'));
if(~isnan(source_current_ac) & ~isnan(source_frequency))
    if(source_current_ac>=2e-9 & source_current_ac<=100e-3 & source_frequency>=1e-3 & source_frequency<=1e5)
        set(hObj, 'Enable', 'off');
        fprintf(ke6221, ['sour:wave:func ', 'sin', line_terminator]);% select sine wave

        fprintf(ke6221, ['sour:wave:freq ', num2str(source_frequency), line_terminator]);% set the frequency
        fprintf(ke6221, ['sour:wave:ampl ', num2str(source_current_ac), line_terminator]);% set the amplitude of the ac 
        fprintf(ke6221, ['sour:wave:offs ', '0', line_terminator]);% no offset
        fprintf(ke6221, ['sour:wave:pmar:stat on', line_terminator]);% Enable phase marker    
        fprintf(ke6221, ['sour:wave:pmar 0', line_terminator]);% set phase marker to 0 degree
    %     fprintf(ke6221, [sour:wave:pmar:olin 3', line_terminator]);% set phase marker to line 3, default
    %     fprintf(ke6221, ['sour:wave:rang best', line_terminator]);% set best fixed source range, default

        fprintf(ke6221, ['sour:wave:arm', line_terminator]);% arms waveform output
        fprintf(ke6221, ['sour:wave:init', line_terminator]);% start waveform output    
    end
end

end

function current_stop(hObj,event, ke6221, h_current_run)

set(h_current_run, 'Enable', 'on');
fprintf(ke6221, 'sour:wave:abor');% stop waveform output

end

function timeconstantup(hObj,event, htime_constant, htime_constant_unit, lock_in830)

time_constant_units=['us,', 'ms,', 's,', 'ks'];
comma_locations=findcommalocations(time_constant_units);
time_constants=[1, 3, 10, 30, 100, 300];

current_time_constant_unit=get(htime_constant_unit,'String');
time_constant_unit_index=unitusing(current_time_constant_unit, time_constant_units);

current_time_constant=str2double(get(htime_constant,'String'));
time_constant_index=valueusing(current_time_constant, time_constants);

if(abs(time_constant_unit_index-(length(comma_locations)+1))<0.01) % the unit is ks
    if(time_constant_index<4)  %maximum is 30 ks
        next_time_constant=time_constants(time_constant_index+1);
        next_time_unit=current_time_constant_unit;
        set(htime_constant,'String', num2str(next_time_constant));   
    else
        next_time_constant=current_time_constant;
        next_time_unit=current_time_constant_unit;
    end
else
    if(abs(time_constant_index-length(time_constants))<0.01)
        next_time_constant=time_constants(1);
        set(htime_constant,'String', num2str(next_time_constant)); 
        if(time_constant_unit_index<length(comma_locations))
            next_time_unit=time_constant_units(comma_locations(time_constant_unit_index)+1:comma_locations(time_constant_unit_index+1)-1);
        else
            next_time_unit=time_constant_units(comma_locations(time_constant_unit_index)+1:length(time_constant_units));
        end
        set(htime_constant_unit,'String', next_time_unit);
    else
        next_time_constant=time_constants(time_constant_index+1);
        next_time_unit=current_time_constant_unit;
        set(htime_constant,'String', num2str(next_time_constant));
    end
end
set_time_constant(next_time_constant, next_time_unit, lock_in830)
end

function timeconstantdown(hObj,event, htime_constant, htime_constant_unit, lock_in830)

time_constant_units=['us,', 'ms,', 's,', 'ks'];
comma_locations=findcommalocations(time_constant_units);
time_constants=[1, 3, 10, 30, 100, 300];

current_time_constant_unit=get(htime_constant_unit,'String');
time_constant_unit_index=unitusing(current_time_constant_unit, time_constant_units);

current_time_constant=str2double(get(htime_constant,'String'));
time_constant_index=valueusing(current_time_constant, time_constants);

if(abs(time_constant_unit_index-1)<0.01) % us
    if(time_constant_index>3)  %mminimum is 10us
        next_time_constant=time_constants(time_constant_index-1);
        next_time_unit=current_time_constant_unit;
        set(htime_constant,'String', num2str(next_time_constant));    
    else
        next_time_constant=current_time_constant;
        next_time_unit=current_time_constant_unit;
    end
else
    if(abs(time_constant_index-1)<0.01)
        next_time_constant=time_constants(length(time_constants));
        set(htime_constant,'String', num2str(next_time_constant)); 
        if(time_constant_unit_index>2)
            next_time_unit=time_constant_units(comma_locations(time_constant_unit_index-2)+1:comma_locations(time_constant_unit_index-1)-1);
        else
            next_time_unit=time_constant_units(1:comma_locations(time_constant_unit_index-1)-1);
        end
        set(htime_constant_unit,'String', next_time_unit);
    else
        next_time_constant=time_constants(time_constant_index-1);
        next_time_unit=current_time_constant_unit;
        set(htime_constant,'String', num2str(next_time_constant));
    end
end
set_time_constant(next_time_constant, next_time_unit, lock_in830)
end

function sentivity_voltageup(hObj,event, hsensitivity, hsensitivity_unit, lock_in830)

sensitivity_units=['nV,', 'uV,', 'mV,', 'V'];
comma_locations=findcommalocations(sensitivity_units);
sensitivities=[1, 2, 5, 10, 20, 50, 100, 200, 500];

current_sensitivity_unit=get(hsensitivity_unit,'String');
sensitivity_unit_index=unitusing(current_sensitivity_unit, sensitivity_units);

current_sensitivity=str2double(get(hsensitivity,'String'));
sensitivity_index=valueusing(current_sensitivity, sensitivities);

if(abs(sensitivity_unit_index-(length(comma_locations)+1))<0.01) % V    
        next_sensitivity=current_sensitivity;
        next_sensitivity_unit=current_sensitivity_unit;
else
    if(abs(sensitivity_index-length(sensitivities))<0.01)
        next_sensitivity=sensitivities(1);
        set(hsensitivity,'String', num2str(next_sensitivity)); 
        if(sensitivity_unit_index<length(comma_locations))
            next_sensitivity_unit=sensitivity_units(comma_locations(sensitivity_unit_index)+1:comma_locations(sensitivity_unit_index+1)-1);
        else
            next_sensitivity_unit=sensitivity_units(comma_locations(sensitivity_unit_index)+1:length(sensitivity_units));
        end
        set(hsensitivity_unit,'String', next_sensitivity_unit);
    else
        next_sensitivity=sensitivities(sensitivity_index+1);
        next_sensitivity_unit=current_sensitivity_unit;
        set(hsensitivity,'String', num2str(next_sensitivity));
    end
end
set_sensitivity(next_sensitivity, next_sensitivity_unit, lock_in830)
end

function sentivity_voltagedown(hObj,event, hsensitivity, hsensitivity_unit, lock_in830)

sensitivity_units=['nV,', 'uV,', 'mV,', 'V'];
comma_locations=findcommalocations(sensitivity_units);
sensitivities=[1, 2, 5, 10, 20, 50, 100, 200, 500];

current_sensitivity_unit=get(hsensitivity_unit,'String');
sensitivity_unit_index=unitusing(current_sensitivity_unit, sensitivity_units);

current_sensitivity=str2double(get(hsensitivity,'String'));
sensitivity_index=valueusing(current_sensitivity, sensitivities);

if(abs(sensitivity_unit_index-1)<0.01) % nV    
    if(sensitivity_index>2)
        next_sensitivity=sensitivities(sensitivity_index-1);
        next_sensitivity_unit=current_sensitivity_unit;
        set(hsensitivity,'String', num2str(next_sensitivity));  
    else
        next_sensitivity=current_sensitivity;
        next_sensitivity_unit=current_sensitivity_unit;
    end
else
    if(abs(sensitivity_index-1)<0.01)
        next_sensitivity=sensitivities(length(sensitivities));
        set(hsensitivity,'String', num2str(next_sensitivity)); 
        if(sensitivity_unit_index>2)
            next_sensitivity_unit=sensitivity_units(comma_locations(sensitivity_unit_index-2)+1:comma_locations(sensitivity_unit_index-1)-1);
        else
            next_sensitivity_unit=sensitivity_units(1:comma_locations(sensitivity_unit_index-1)-1);
        end 
        set(hsensitivity_unit,'String', next_sensitivity_unit);
    else
        next_sensitivity=sensitivities(sensitivity_index-1);
        next_sensitivity_unit=current_sensitivity_unit;
        set(hsensitivity,'String', num2str(next_sensitivity));
    end
end
set_sensitivity(next_sensitivity, next_sensitivity_unit, lock_in830)
end

function Refresh_all_current(hObj,event,lock_in830,htime_constant,htime_constant_unit,hsensitivity,hsensitivity_unit,href_frequency,hharmonic,hA,hAB,hAC,hDC)

[time_constant, time_constant_unit]=read_time_constant(lock_in830);
set(htime_constant, 'String', num2str(time_constant));
set(htime_constant_unit, 'String', time_constant_unit);
[sensitivity_voltage, sensitivity_unit]=read_sensitivity(lock_in830);
set(hsensitivity, 'String', num2str(sensitivity_voltage));
set(hsensitivity_unit, 'String', sensitivity_unit);

fprintf(lock_in830, 'FREQ?'); 
current_frequency=str2double(fscanf(lock_in830));
set(href_frequency, 'String', num2str(current_frequency));

fprintf(lock_in830, 'HARM?'); 
current_harmonic=str2double(fscanf(lock_in830));
set(hharmonic, 'String', num2str(current_harmonic));

fprintf(lock_in830, 'ISRC?'); 
current_input=str2double(fscanf(lock_in830));
if(abs(current_input)<1e-10)
    set(hA, 'Value', 1);
    set(hAB, 'Value', 0);
else
    set(hA, 'Value', 0);
    set(hAB, 'Value', 1);
end

fprintf(lock_in830, 'ICPL?'); 
current_ACDC=str2double(fscanf(lock_in830));
if(abs(current_ACDC)<1e-10)
    set(hAC, 'Value', 1);
    set(hDC, 'Value', 0);
else
    set(hAC, 'Value', 0);
    set(hDC, 'Value', 1);
end

end

function Refresh_all(hObj,event,lock_in830,htime_constant,htime_constant_unit,hsensitivity,hsensitivity_unit,href_frequency,hvoltage,hharmonic,hA,hAB,hAC,hDC)

[time_constant, time_constant_unit]=read_time_constant(lock_in830);
set(htime_constant, 'String', num2str(time_constant));
set(htime_constant_unit, 'String', time_constant_unit);
[sensitivity_voltage, sensitivity_unit]=read_sensitivity(lock_in830);
set(hsensitivity, 'String', num2str(sensitivity_voltage));
set(hsensitivity_unit, 'String', sensitivity_unit);

fprintf(lock_in830, 'FREQ?'); 
current_frequency=str2double(fscanf(lock_in830));
set(href_frequency, 'String', num2str(current_frequency));

fprintf(lock_in830, 'SLVL?'); 
current_voltage=str2double(fscanf(lock_in830));
set(hvoltage, 'String', num2str(current_voltage));

fprintf(lock_in830, 'HARM?'); 
current_harmonic=str2double(fscanf(lock_in830));
set(hharmonic, 'String', num2str(current_harmonic));

fprintf(lock_in830, 'ISRC?'); 
current_input=str2double(fscanf(lock_in830));
if(abs(current_input)<1e-10)
    set(hA, 'Value', 1);
    set(hAB, 'Value', 0);
else
    set(hA, 'Value', 0);
    set(hAB, 'Value', 1);
end

fprintf(lock_in830, 'ICPL?'); 
current_ACDC=str2double(fscanf(lock_in830));
if(abs(current_ACDC)<1e-10)
    set(hAC, 'Value', 1);
    set(hDC, 'Value', 0);
else
    set(hAC, 'Value', 0);
    set(hDC, 'Value', 1);
end

end

function set_harmonic(hObj,event, lock_in830, hharmonic)

harmonic_number=get(hharmonic, 'String');
if(~isnan(str2double(harmonic_number)))
    fprintf(lock_in830, ['HARM ', harmonic_number,' <lf>']); %sets or queries the detection harmonic
end

end

function set_voltage(hObj,event, lock_in830, href_frequency, hvoltage, hharmonic)

harmonic_number=get(hharmonic, 'String');
if(~isnan(str2double(harmonic_number)))
    fprintf(lock_in830, ['HARM ', harmonic_number,' <lf>']); %sets or queries the detection harmonic
end
current_frequency=get(href_frequency, 'String');
if(~isnan(str2double(current_frequency)))
    fprintf(lock_in830, ['FREQ ', current_frequency,' <lf>']); %sets or queries the detection harmonic
end
current_voltage=str2double(get(hvoltage, 'String'));
if(~isnan(current_voltage))
    if(current_voltage<0.004)
        current_voltage=0.004;
    elseif(current_voltage>5)
        current_voltage=5;
    end
    fprintf(lock_in830, ['SLVL ', num2str(current_voltage),' <lf>']); %sets or queries the detection harmonic
end

end

function setA(hObj,event, lock_in830, hAB) 

set(hObj, 'Value', 1);
set(hAB, 'Value', 0);
fprintf(lock_in830, ['ISRC ', num2str(0),' <lf>']); 

end

function setAB(hObj,event, lock_in830, hA) 

set(hObj, 'Value', 1);
set(hA, 'Value', 0);
fprintf(lock_in830, ['ISRC ', num2str(1),' <lf>']); 

end

function setAC(hObj,event, lock_in830, hDC) 

set(hObj, 'Value', 1);
set(hDC, 'Value', 0);
fprintf(lock_in830, ['ICPL ', num2str(0),' <lf>']); 

end

function setDC(hObj,event, lock_in830, hAC) 

set(hObj, 'Value', 1);
set(hAC, 'Value', 0);
fprintf(lock_in830, ['ICPL ', num2str(1),' <lf>']); 

end

function take_data(hObj,event, lock_in830, hsub1, hsub2, current_source,h_1, h_2, plot_delta_t)

phase_range=0; %if 1, change the negative phase to positive, 0, no change, -1, change positive to negative
if(current_source)
    name_current=get(h_1,'String');
    name_frequency=get(h_2, 'String');
    file_fullname=['Current_',name_frequency, ' Hz_', name_current,' A','.txt'];
else
    name_voltage=get(h_1, 'String');
    name_frequency=get(h_2, 'String');
    file_fullname=['Voltage_',name_frequency,' Hz_', name_voltage,' V','.txt'];
end

set(hObj, 'Enable', 'off');
set(hObj, 'Value', 0);
count=1e6;
array_size=1e4;
delta_t=plot_delta_t;

data_array=zeros(array_size,2);
time_lapse=zeros(array_size,1);
for(ii=1:array_size)
    time_lapse(ii)=(ii-1)*delta_t;
end

% file_fullname='amplitude_phase.txt';

str_len=length(file_fullname);
file_name=file_fullname(1:str_len-4);
file_extension=file_fullname(str_len-2:str_len);
     
for(ii=1:5)
    if(ii<=10)
        file_number=['0', int2str(ii-1)];
    else
        file_number=int2str(ii-1);
    end
    if(exist(file_fullname))
        if(~exist([file_number,file_name,'.',file_extension]))
            new_file_name=[file_number,file_name,'.',file_extension];
            movefile(file_fullname,new_file_name);
            break;
        end        
    end
end
current_file_name=file_fullname;
fp=fopen(current_file_name, 'w+');

for(ii=1:count)
    fprintf(lock_in830, 'OUTP? 3 <lf>');
    temp_amplitude=str2double(fscanf(lock_in830));   
    if(ii<=array_size)
        data_array(ii,1)=temp_amplitude;
    else
        data_array(1:array_size-1,1)=data_array(2:array_size,1);
        data_array(array_size,1)=temp_amplitude;  
    end
    fprintf(lock_in830, 'OUTP? 4 <lf>');
    temp_phase=str2double(fscanf(lock_in830)); 
        if(phase_range==1)
        if(temp_phase<0)
            temp_phase=temp_phase+360;
        end
    elseif(phase_range==-1)
        if(temp_phase>0)
            temp_phase=temp_phase-360;
        end
    end
    if(ii<=array_size)
        data_array(ii,2)=temp_phase;
    else
        data_array(1:array_size-1,2)=data_array(2:array_size,2);
        data_array(array_size,2)=temp_phase;  
    end
    fprintf(fp,'%10.7g\t%10.7g\r\n', temp_amplitude, temp_phase);
    pause(delta_t);
           
    subplot(hsub1);    
    if(ii<array_size)
        plot(time_lapse(1:ii,1), data_array(1:ii,1));   
        max_amp=max(data_array(1:ii,1))+1e-10;
        min_amp=min(data_array(1:ii,1))-1e-10;
    else
        plot(time_lapse(:,1), data_array(:,1));
        max_amp=max(data_array(:,1))+1e-10;
        min_amp=min(data_array(:,1))-1e-10;
    end
    plot_limit=get(hObj, 'UserData');
    if(abs(max_amp)<1e-10 & abs(min_amp)<1e-10)
        max_amp=1e-10;
        min_amp=-1e-10;
    end 
    if(abs(plot_limit(1))<1e-12 & abs(plot_limit(2))<1e-12)
    	ylim([0.995*min_amp,1.005*max_amp]);
    elseif(abs(plot_limit(1))>1e-12 & abs(plot_limit(2))<1e-12)
        ylim([plot_limit(1)-(max_amp-min_amp)/2, plot_limit(1)+(max_amp-min_amp)/2]);
    elseif(abs(plot_limit(1))<1e-12 & abs(plot_limit(2))>1e-12)
        ylim([(max_amp+min_amp)/2-plot_limit(2)/2, (max_amp+min_amp)/2+plot_limit(2)/2]);
    else
        ylim([plot_limit(1)-plot_limit(2)/2, plot_limit(1)+plot_limit(2)/2]);
    end
    grid on;
    subplot(hsub2)
    if(ii<array_size)
        plot(time_lapse(1:ii,1), data_array(1:ii,2));
        max_phase=max(data_array(1:ii,2))+1e-10;
        min_phase=min(data_array(1:ii,2))-1e-10;
    else
        plot(time_lapse(:,1),data_array(:,2));
        max_phase=max(data_array(:,2))+1e-10;
        min_phase=min(data_array(:,2))-1e-10;
    end  
    if(abs(max_phase)<1e-10 & abs(min_phase)<1e-10)
        max_phase=1e-10;
        min_phase=-1e-10;
    end
    if(abs(plot_limit(3))<1e-12 & abs(plot_limit(4))<1e-12)
        if(min_phase<0 & max_phase<0)
            ylim([1.001*min_phase,0.999*max_phase]);
        elseif(min_phase<0 & max_phase>0)
            ylim([1.001*min_phase,1.001*max_phase]);
        else
            ylim([0.999*min_phase,1.001*max_phase]);
        end
    elseif(abs(plot_limit(3))>1e-12 & abs(plot_limit(4))<1e-12)
        ylim([plot_limit(3)-(max_phase-min_phase)/2, plot_limit(3)+(max_phase-min_phase)/2]);
    elseif(abs(plot_limit(3))<1e-12 & abs(plot_limit(4))>1e-12)
        ylim([(max_phase+min_phase)/2-plot_limit(4)/2, (max_phase+min_phase)/2+plot_limit(4)/2]);
    else
        ylim([plot_limit(3)-plot_limit(4)/2, plot_limit(3)+plot_limit(4)/2]);
    end
    grid on;
    if(get(hObj, 'Value'))  
        fclose(fp);
        set(hObj, 'Enable', 'on');
        break;
    end
end

end

function stop_data(hObj,event, htake_data)

set(htake_data, 'Value', 1);

end

function [current_time, current_unit]=read_time_constant(lock_in830)

time_constant_range = [10e-6; 30e-6; 100e-6;300e-6;1e-3;3e-3;10e-3;30e-3;100e-3;300e-3;1;3;10;30;100;300;1e3;3e3;10e3;30e3];
%OFLT (?) {i}  Set (Query) the Time Constant to 10 us (0) through 30 ks
%(19)for SR830; 

fprintf(lock_in830, 'OFLT?');    
current_time_constant_index=str2double(fscanf(lock_in830));
current_time_constant_index
if(current_time_constant_index<=3)
    current_time=time_constant_range(current_time_constant_index+1)/1e-6;
    current_unit='us';
elseif (current_time_constant_index>3 & current_time_constant_index<=9)
    current_time=time_constant_range(current_time_constant_index+1)/1e-3;
    current_unit='ms';
elseif (current_time_constant_index>9 & current_time_constant_index<=15)
    current_time=time_constant_range(current_time_constant_index+1);
    current_unit='s';
else 
    current_time=time_constant_range(current_time_constant_index+1)/1e3;    
    current_unit='ks';
end

end

function set_time_constant(time, unit, lock_in830)
current_time=0;
switch unit
    case 'us'
        current_time=time*1e-6;
    case 'ms'
        current_time=time*1e-3;
    case 's'
        current_time=time;
    case 'ks'
        current_time=time*1e3;
end
time_constant_range = [10e-6; 30e-6; 100e-6;300e-6;1e-3;3e-3;10e-3;30e-3;100e-3;300e-3;1;3;10;30;100;300;1e3;3e3;10e3;30e3];
%OFLT (?) {i}  Set (Query) the Time Constant to 10 us (0) through 30 ks
%(19)for SR830; 100?s (0) through 30 ks (17) for SR 844
for(ii=1:length(time_constant_range))
    if(abs(current_time-time_constant_range(ii))<1e-10)
        time_constant_index=ii-1;
        break;
    end
end
fprintf(lock_in830, ['OFLT ',num2str(time_constant_index),'<lf>']);

end

function [current_sensitivity, current_unit]=read_sensitivity(lock_in830)

sensitivity_range = [2e-9; 5e-9; 10e-9; 20e-9; 50e-9; 100e-9; 200e-9; 500e-9;
    1e-6; 2e-6; 5e-6; 10e-6; 20e-6; 50e-6; 100e-6;200e-6; 500e-6;
    1e-3; 2e-3; 5e-3; 10e-3; 20e-3; 50e-3; 100e-3;200e-3; 500e-3; 1];

fprintf(lock_in830, 'SENS?');    
current_sensitivity_index=str2double(fscanf(lock_in830));
if(current_sensitivity_index<=7)
    current_sensitivity=sensitivity_range(current_sensitivity_index+1)/1e-9;
    current_unit='nV';
elseif (current_sensitivity_index>7 & current_sensitivity_index<=16)
    current_sensitivity=sensitivity_range(current_sensitivity_index+1)/1e-6;
    current_unit='uV';
elseif (current_sensitivity_index>16 & current_sensitivity_index<=25)
    current_sensitivity=sensitivity_range(current_sensitivity_index+1)/1e-3;
    current_unit='mV';
else 
    current_sensitivity=sensitivity_range(current_sensitivity_index+1);    
    current_unit='V';
end

end

function set_sensitivity(sensitivity, unit, lock_in830)
current_sensitivity=0;
switch unit
    case 'nV'
        current_sensitivity=sensitivity*1e-9;
    case 'uV'
        current_sensitivity=sensitivity*1e-6;
    case 'mV'
        current_sensitivity=sensitivity*1e-3;
    case 'V'
        current_sensitivity=sensitivity;
end
sensitivity_range = [2e-9; 5e-9; 10e-9; 20e-9; 50e-9; 100e-9; 200e-9; 500e-9;
    1e-6; 2e-6; 5e-6; 10e-6; 20e-6; 50e-6; 100e-6;200e-6; 500e-6;
    1e-3; 2e-3; 5e-3; 10e-3; 20e-3; 50e-3; 100e-3;200e-3; 500e-3; 1];
%SENS (?) {i}  Set (Query) the sensitivity to 2nV (0) through 1V
%(26)for SR830; 
for(ii=1:length(sensitivity_range))
    if(abs(current_sensitivity-sensitivity_range(ii))<1e-10)
        sensitivity_index=ii-1;
        break;
    end
end
fprintf(lock_in830, ['SENS ',num2str(sensitivity_index),'<lf>']);

end

function comma_locations=findcommalocations(unitstr)
str_unit_length=length(unitstr);
comma_locations=[];
comma_number=0;

for(ii=1:str_unit_length)
    if(strcmp(unitstr(ii),','))
        comma_number=comma_number+1;
        comma_locations(comma_number)=ii;
    end
end

end
function index=valueusing(current_value, values)

for(ii=1:length(values))
    if(abs(current_value-values(ii))<0.01)
        index=ii;
        break;
    end
end

end

function index=unitusing(current_unit, units)

comma_locations=findcommalocations(units);
for(ii=1:length(comma_locations)+1)
    if(ii==1)
        temp_unit=units(1:comma_locations(ii)-1);
    elseif(ii==length(comma_locations)+1)
        temp_unit=units(comma_locations(ii-1)+1:length(units));
    else
        temp_unit=units(comma_locations(ii-1)+1:comma_locations(ii)-1);
    end
    if(strcmp(current_unit, temp_unit))
        index=ii;
        break;
    end
end

end

function clear_amp_change(hObj,event, htake_data, h_amp_center, h_amp_scope)
settings=get(htake_data, 'UserData');
settings(1)=0;
settings(2)=0;
set(htake_data,'UserData', settings);
set(h_amp_center, 'String', num2str(0));
set(h_amp_scope, 'String', num2str(0));
end

function set_amp_center(hObj,event, htake_data,h_amp_center)
amp_center=str2double(get(h_amp_center, 'String'));
if(~isnan(amp_center))
    original_setting=get(htake_data, 'UserData');
    original_setting(1)=amp_center;
    set(htake_data,'UserData', original_setting);
end

end

function set_amp_scope(hObj,event, htake_data,h_amp_scope)
amp_scope=str2double(get(h_amp_scope, 'String'));
if(~isnan(amp_scope))
    original_setting=get(htake_data, 'UserData');
    original_setting(2)=amp_scope;
    set(htake_data,'UserData', original_setting);
end

end

function clear_phase_change(hObj,event, htake_data, h_phase_center,h_phase_scope)
settings=get(htake_data, 'UserData');
settings(3)=0;
settings(4)=0;
set(htake_data,'UserData', settings);
set(h_phase_center, 'String', num2str(0));
set(h_phase_scope, 'String', num2str(0));
end

function set_phase_center(hObj,event, htake_data,h_phase_center)
phase_center=str2double(get(h_phase_center, 'String'));
if(~isnan(phase_center))
    original_setting=get(htake_data, 'UserData');
    original_setting(3)=phase_center;
    set(htake_data,'UserData', original_setting);
end

end

function set_phase_scope(hObj,event, htake_data,h_phase_scope)
phase_scope=str2double(get(h_phase_scope, 'String'));
if(~isnan(phase_scope))
    original_setting=get(htake_data, 'UserData');
    original_setting(4)=phase_scope;
    set(htake_data,'UserData', original_setting);
end

end
