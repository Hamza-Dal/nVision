
function [mne,sd,kur,skew] = nonlinearenergy22 (data)
data=data';
ne= data.^2.- ([data(2:length(data)) 0]).*([0 data(1:(length(data)-1))]);
mne = mean(ne);
sd= std(ne);
kur= kurtosis(ne);
skew = skewness(ne);
end
