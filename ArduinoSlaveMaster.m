clear;clc;close all

%----Establish LIA Connection----%
lock_in830= instrfind('Type', 'visa-gpib');
if(isempty(lock_in830))
    lock_in830=visa('ni','GPIB0::8::INSTR');
%     lock_in830=visa('agilent','GPIB0::8::INSTR');
else
    fclose(lock_in830);
end
fopen(lock_in830);

%     VARIABLES       %
timeConstant = 3000; %millisenconds%
sample = 1000;

%Start Serial Connection%
s = serialport("COM7",115200);

%----Main Code----%
iterationCount = 80; %Don't increase to avoid sample collision.

% Set time constant in LIA %
set_time_constant(300, 'ms', lock_in830);

%Collect the CamelFocus Data
confPosition = zeros(1,iterationCount);
ampValue = zeros(1,iterationCount);

for i = 1:iterationCount
    confPosition(i) = setFine(s,50+i)
    
    % pause before each data aquisition to allow the LIA to settle on the true value %
    %pause((0.0015*timeConstant));
    
    %Probing the LIA and receiving data.
    fprintf(lock_in830, 'OUTP? 3 <lf>');
    ampValue(i) = str2double(fscanf(lock_in830));
    
end

%Detect Symmetry
margin = 20;

deviationVector = zeros(1,length(confPosition) - 2*margin);
deviationLocation = zeros(1,length(confPosition) - 2*margin);

for i = margin + 1:length(confPosition) - margin
    deviationVector(i - margin) = 0;
    rangeRadius = min(i - 1,length(confPosition) - i);
    for j = 1:rangeRadius
        deviationVector(i - margin) = deviationVector(i - margin) + (ampValue(i - j) - ampValue(i + j))^2;
    end
    deviationVector(i - margin) = deviationVector(i - margin)/rangeRadius;
    deviationLocation(i - margin) = confPosition(i);
end

[~,symIdx] = min(deviationVector);
symCenter = deviationLocation(symIdx);
[~,symIdx2] = max(ampValue);
symCenter2 = confPosition(symIdx2);


plot(confPosition,ampValue)
hold on

testCase = inputdlg("Focus Position: " + symCenter + " or " + symCenter2 + ". Please enter new position.", "Center Line",[1 35], {int2str(symCenter2)})
symCenter = str2num(testCase{1});
xline(symCenter);

setFine(s,symCenter);
%-----------------%

servoPos = 1:10;
set_time_constant(timeConstant, 'ms', lock_in830);
% Aquire data %
for i = servoPos
    
    setServo(s,i+7)
    
    for j = 1:sample

          %Probing the LIA and receiving data.
        fprintf(lock_in830, 'OUTP? 3 <lf>');
        ampData(i,j) = str2double(fscanf(lock_in830));
        fprintf(lock_in830, 'OUTP? 4 <lf>');
        phaseData(i,j) = str2double(fscanf(lock_in830));
    
    end
    
    pause((0.015 * timeConstant));
end

setServo(s,8);
%Close Serial Connection
s = [];

save("testSave"+"_"+date()+"_"+hour(now())+"_"+minute(now()))

plot([8 9 10 11 12 13 14 15 16 17],mean(phaseData'))

function [confPosition] = setFine(serialObject, finePos)
    writeline(serialObject,"FINEPOS:"+finePos+";");
    
    confPosition = readline(serialObject);
    
end

function [confPosition] = setServo(serialObject, finePos)
    writeline(serialObject,"SERVO:"+finePos+";");
    
    confPosition = readline(serialObject);
    
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




