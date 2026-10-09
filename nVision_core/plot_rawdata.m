function plot_data (data,xaxes,rate,lims)
cla reset;
p_data = plot (data,'Color',[0.5,0,0.5]');
axis tight;
ylim (lims);
ylabel ('Amplitude [mV]','color','white');
set (gca,'XColor', 'white','YColor', 'white','XTick',[]);

end
