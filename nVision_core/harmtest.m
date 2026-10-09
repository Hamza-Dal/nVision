function [size1]  = harmtest (data,rate)
%the precent of auto-corelation of the signle in the typicale seizure activty
%range.
auto = xcorr (data); 
auto = normc(auto);
[val,pos] = max(auto);
auto = auto(pos+floor(rate/3.333):pos+floor(rate/2));
[size1,place1] = max(auto);
end
