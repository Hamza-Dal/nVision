function [x] = parameters5_anyrate (data,rate)
%calculates the desired features and stacks them in a vector
stdev = std(data);
l = sum(abs(diff(data)));%the overall length of the signal
% maxd= max(abs(data));
% % peak = maxd/stdev;
% kur = kurtosis(data);
energy = mean (data  .^2);
%FD = calc_FD(data'); % calculate the fractle dimnsion of the window using box counting
% [size1]  = harmtest (data,rate);
% xaxes = [1:length(data)];
%lpcfeatures = lpc(data,6)';
%lpcfeatures = lpcfeatures(2:7);
% zerocross = length(findX(xaxes',data,0));
% cumarea=cumtrapz(data);
% lastarea=cumarea(end);
% [kurne,skewne] = nonlinearenergy (data);
% [stdfft,kurfft,skewfft,medianfft] = fftfeatures (data);
[amp12to20,amp20to40] = fftfeaturesbands_anyrate(data,rate);
% x = [energy;FD;stdev;l;maxd;peak;kur;size1;zerocross;lastarea;mne;sdne;kurne;skewne;stdfft;kurfft;skewfft;medianfft;amp3to8,amp8to12,amp12to20,amp20to40];
% x
% =[energy;stdev;l;peak;kurne;skewne;amp3to8;amp8to12;amp12to20;amp20to40];% 10features

x = [energy;stdev;l;amp12to20;amp20to40];% 5features


% [1;22;4;3;21;20;6;19;14;13]
% x = [
%     energy;
%     FD;
%     stdev;
%     l;
%     maxd;
%     peak;
%     kur;
%     size1;
%     zerocross;
%     lastarea;
%     mne;
%     sdne;
%     kurne;
%     skewne;
%     stdfft;
%     kurfft;
%     skewfft;
%     medianfft;
%     amp3to8,
%     amp8to12,
%     amp12to20,
%     amp20to40];