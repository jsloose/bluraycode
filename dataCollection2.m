%----Establish LIA Connection----%
lock_in830= instrfind('Type', 'visa-gpib');
if(isempty(lock_in830))
    lock_in830=visa('ni','GPIB0::8::INSTR');
%     lock_in830=visa('agilent','GPIB0::8::INSTR');
else
    fclose(lock_in830);
end
fopen(lock_in830);




% Set time constant in LIA %
set_time_constant(300, 'ms', lock_in830);



%Probing the LIA and receiving data.
fprintf(lock_in830, 'OUTP? 3 <lf>');
ampValue(i) = str2double(fscanf(lock_in830));


fprintf(lock_in830, 'OUTP? 3 <lf>');
ampData(i,j) = str2double(fscanf(lock_in830));
fprintf(lock_in830, 'OUTP? 4 <lf>');
phaseData(i,j) = str2double(fscanf(lock_in830));


