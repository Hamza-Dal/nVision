function [days,hours,minutes,secunds]= convert_to_date (sec)
days =int2str( floor(sec/86400));
sec = mod (sec,86400);
hours = int2str(floor(sec/3600));
sec = mod (sec,3600);
minutes = int2str(floor(sec/60));
secunds =int2str( mod (sec,60));
end
