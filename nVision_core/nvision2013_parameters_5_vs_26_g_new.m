%% nVision
% An algorithm for seizure detection in rodents
%
% Kamintsky L, van Hameren G, Weissberg I, Moradi P,
% Prager O, Ahmad AA, Schori L, Becker A,
% Zigel Y, Friedman A.
% An algorithm for seizure detection in rodents.
% Epilepsia Open. 2025 Jun 4. doi: 10.1002/epi4.70070.
% PMID: 40464255.
%
% Syntax:  nvision2013_parameters_5_vs_26_g_new.m
%
% Inputs:
%    ECoG data stored in .dat format.
%
% Outputs:
%    MATLAB and excel files containing analysis results.
%
% Author: BBBLab
% Contact: alon.friedman@gmail.com; hamza@dal.ca
% Website: https://www.bbbscience.com/
% August 2025

function nvision2013_parameters_5_vs_26_g_new

global  time_points TrainingFolder LoadedTrainingFile NetFolder automaticquiet TrainingAnimalNames UseAnimalinTraining CurrentTrainingAnimalName
NetFolder =[pwd '\Networks\'];
TrainingFolder=[pwd '\Training\'];
%TrainingFolder=[pwd '\Test Net\Full3\'];

%global LoadedNetDir LoadedNetFile LoadedNets

automaticquiet=false;
time_points = {[],[],[],[],[]}; %first cell = seizure, second = quiet, third cell = use seizure in training, fourth = use quiet in training
%%%%%%%%%%%

f = figure('Visible','off','Position',[1024,720,1024,720],'WindowState','maximized','Color',[ 0.1 , 0.15 , 0.1 ],'Name','Nvision','NumberTitle','off',...
    'MenuBar','none','KeyPressFcn',{@keypress_Callback});%ERASE THIS TO ENABLE SAVING A TIFF
%% DELETE ALL WHEN CLOSING NVISION
% Create template for Nvision software, namely a save and close callback
% and loading a background image

% set(gcf, 'CloseRequestFcn', 'close all; clear all; clc');
set(gcf, 'CloseRequestFcn', {@close_Callback});
% % % % % % % % % % % % %         /\
% % % % % % % % % % % % %        | ||
% % % % % % % % % % % % %        | ||
haa= axes('position',[0,0,1,1]);
I=imread('12f.jpg');
hi = imagesc(I);
set (gca,'Visible','off');
teal=rgb('teal');

%% %TOMER%%
hloadpanel = uipanel('Parent',f,'Units','Pixels','Position',[10,530,550,187],'BackgroundColor','black','ShadowColor',[0 0 0],'ForegroundColor',teal);
htrainpanel = uipanel('Parent',f,'Units','Pixels','Position',[10,530,550,187],'Visible','off','BackgroundColor','black','ShadowColor',[0 0 0],'ForegroundColor',teal);
%% DATA ANALYSIS CONTROLS
% Column 1
hload    = uicontrol('Parent',hloadpanel,'Style','pushbutton','String','Load Raw Signal ','Position',[15,150,160,25],'Callback',{@loadbutton_Callback},'BackgroundColor',teal,'ForegroundColor','w','FontSize',10);
hraw  = uicontrol('Parent',hloadpanel,'Style','text','String','File Name (.dat) ','Position',[15,122,160,27],'BackgroundColor','white','FontSize',8);
hsavedir    = uicontrol('Parent',hloadpanel,'Style','pushbutton','String','Select Feature Folder ','Position',[15,85,160,25],'Callback',{@dirbutton_Callback},'BackgroundColor',teal,'ForegroundColor','w','FontSize',10);
hdir  = uicontrol('Parent',hloadpanel,'Style','text','String','Folder Name','Position',[15,60,160,23],'BackgroundColor','white');
hfeature    = uicontrol('Parent',hloadpanel,'Style','pushbutton','String','Calculate Features','Position',[15,10,160,35],'Callback',{@featurebutton_Callback},'BackgroundColor',teal,'ForegroundColor','w','FontSize',10,'FontWeight','bold');

% Column 2
hSSbutton = uicontrol('Parent',hloadpanel,'Style','pushbutton','String','Use Current View as Quiet','Position',[205,150,160,25],'Callback',{@Qsavebutton_Callback},'BackgroundColor',teal,'ForegroundColor','w','FontSize',10);

hQbutton = uicontrol('Parent',hloadpanel,'Style','pushbutton','String','Load Quiet Segment','Position',[205,115,160,25],'Callback',{@quietbutton_Callback},'BackgroundColor',teal,'ForegroundColor','w','FontSize',10);
hQuiet  = uicontrol('Parent',hloadpanel,'Style','text','String','File Name','Position',[205,90,160,23],'BackgroundColor','white');
dynamicQbutton = uicontrol('Parent',hloadpanel,'Style','togglebutton','String','Use Dynamic Scaling','Position',[205,55,160,25],'BackgroundColor',teal,'ForegroundColor','w','FontSize',10);
hclassify    = uicontrol('Parent',hloadpanel,'Style','pushbutton','String','Classify Features','Position',[205,10,160,35],'Callback',{@classifybutton_Callback},'BackgroundColor',teal,'ForegroundColor','w','FontSize',10,'FontWeight','bold');

% Column 3
hplottable =uitable( 'Parent',hloadpanel, 'Position',[390,107,150,65],...
    'ColumnName',{'Net Name','Plot','TimeLines'},...
    'ColumnWidth', {'auto' 35 35},...
    'Data',{[] [] []},...
    'FontSize',10,...
    'ColumnFormat', {'char','logical' ,'logical'},...
    'ColumnEditable', [false true true],...
    'CellEditCallback',  {@EditPlotTable_Callback});

hloadstarts = uicontrol('Parent',hloadpanel,'Style','pushbutton','String','Load Previous Results','Position',[390,75,150,25],'Callback',{@Coordinates_Callback},'BackgroundColor',teal,'ForegroundColor','w','FontSize',10);
hstarts = uicontrol('Parent',hloadpanel,'Style','text','String','xls\csv\mat','Position',[390,50,150,23],'BackgroundColor','white');
hsbutton = uicontrol('Parent',hloadpanel,'Style','pushbutton','String','Save Results','Position',[390,15,150,25],'Callback',{@savebutton_Callback},'BackgroundColor',teal,'ForegroundColor','w','FontSize',10);

%% COLUMN 4
hlistyn    = uicontrol('Style','text','String','Events','Position',[572,685,186,15],'BackgroundColor',teal,'ForegroundColor','w','FontSize',9);
%% EVENTS TABLE
dat =  {[], '', '', '' , '' , '' , '' , '' , [],false};
columnformat = {'char', 'char', 'char', 'char', 'char', 'char', 'char', 'char', {' ' 'Log' 'Seizure' 'InterIctal' 'Noise'}, 'logical'};
columneditable =  [false false false false false false false false true true ];
htable    = uitable( 'Parent',f, 'Position',[572,550,186,135],...
    'units','Normalized',...
    'ColumnName',{'Start','Dur','WLen','WCnt', 'Pct', 'ANNPosAvg', 'WnANNAvg', 'ANNAvg', 'Class',''},...
    'ColumnWidth', { 65 50 50 50 50 55 75 75 'auto' 20},...
    'Data',dat,...
    'FontSize',10,...
    'ColumnFormat', columnformat,...
    'ColumnEditable', columneditable,...
    'CellSelectionCallback',  {@select_Callback});
hadd    = uicontrol('Style','pushbutton','String','Mark Event','Position',[572,530,160,15],'BackgroundColor',teal,'ForegroundColor','w','FontSize',9,'Callback',{@selectpointsbutton_Callback});
hadl    = uicontrol('Style','pushbutton','String','X','Position',[737,530,20,15],'BackgroundColor',teal,'ForegroundColor','w','FontSize',9,'Callback',{@deletepointsbutton_Callback},'tooltip','Delete checked rows in table');


%% TOMER %% Training  panel controls

global CurrentAnimal TrainingFileInfo CurrentAnimalIndex;
global struct_name;
CurrentAnimalIndex=1;

hselectanimal_table = uitable( 'Parent',htrainpanel, 'Position',[15,70,180,110],...
    'ColumnName',{'Animal Name','Use in Training'},...
    'ColumnFormat',{'char','logical'},...
    'ColumnWidth', { 70 70},...
    'ColumnEditable', [false true],...
    'Data',{'New Animal', true},...
    'FontSize',10,...
    'CellSelectionCallback',{@SelectAnimalTable_Callback});
UpdateAnimalsTable();

hselectiontype_popup  = uicontrol('Parent',htrainpanel,'Style','popupmenu','String','Select Seizure (u)|Select Quiet (q)','Position',[15,40,160,25],'BackgroundColor','w','ForegroundColor','b','FontSize',10,'Callback',{@selectiontypepopup_Callback});
hselectpointsbutton = uicontrol('Parent',htrainpanel,'Style','pushbutton','String','Select Points (s)','Position',[15,10,160,25],'Callback',{@selectpointsbutton_Callback},'BackgroundColor',teal,'ForegroundColor','w','FontSize',10);

global point_type;
point_type = get(hselectiontype_popup,'Value'); %records whether the user wants to select quiet or seizure.

htimepoints_table    = uitable( 'Parent',htrainpanel, 'Position',[205,70,180,110],...
    'ColumnName',{'Start Time','End Time','Use in Training','Norm to Quiet?'},...
    'ColumnFormat',{'numeric','numeric','logical','logical'},...
    'ColumnWidth', { 70 70 70},...
    'ColumnEditable', [true true true false],...
    'Data',[],...
    'FontSize',10,...
    'CellSelectionCallback',{@timepointstableselected_Callback},...
    'CellEditCallback',{@timepointstableedit_Callback});
timepoints_table_rowsselected=[];

%%TOMER%%
hremoverows_button =uicontrol('Parent',htrainpanel,'Style','pushbutton','String','Remove Selected Rows','Position',[205,35,160,25],'Callback',{@removerowsbutton_Callback},'BackgroundColor',teal,'ForegroundColor','w','FontSize',10);
hautoselectnormalizationquiet_checkbox =uicontrol('Parent',htrainpanel,'Style','checkbox','String','Auto Normalization Quiet','Position',[205,5,160,25],'Callback',{@AutoSelectNormalizationQuietCheckbox_Callback},'BackgroundColor',[0 .25 .25],'ForegroundColor','w','FontSize',8);

hsaveanimal_button =uicontrol('Parent',htrainpanel,'Style','pushbutton','String','Save Current Animal','Position',[390,120,150,25],'Callback',{@SaveAnimalButton_Callback},'BackgroundColor',teal,'ForegroundColor','w','FontSize',10);
hselecttraintype_popup  = uicontrol('Parent',htrainpanel,'Style','popupmenu','String','Do not subdivide|Subdivide|Subdivide incrementally','Position',[390,80,150,25],'BackgroundColor','w','ForegroundColor','b','FontSize',10,'Callback',{@traintypepopup_Callback});

hnumberofsegments_text = uicontrol('Parent',htrainpanel,'Style','text','String','Number of Segments:','Position',[385,55,105,25],'FontSize',8,'BackgroundColor',[0 .25 .25],'ForegroundColor','w');
hnumberofsegments_edit = uicontrol('Parent',htrainpanel,'Style','edit','String','5','Position',[490,67,50,12],'Callback',{@NumberOfSegmentsEdit_Callback});

hlengthofsegments_text = uicontrol('Parent',htrainpanel,'Style','text','String','Duration in Seconds:','Position',[385,40,105,25],'FontSize',8,'BackgroundColor',[0 .25 .25],'ForegroundColor','w');
hlengthofsegments_edit = uicontrol('Parent',htrainpanel,'Style','edit','String','2','Position',[490,52,50,12],'Callback',{@LengthOfSegmentsEdit_Callback});

htrain_button =uicontrol('Parent',htrainpanel,'Style','pushbutton','String','Train New Network','Position',[390,5,150,25],'Callback',{@TrainButton_Callback},'BackgroundColor',teal,'ForegroundColor','w','FontSize',10);
%% NAVIGATION CONTROLS
%%
% Column 6
hgbutton  = uicontrol('Style','text','String','Go To [sec]','Position',[910,680,100,20]);
hgoto = uicontrol('Style','edit','String','0','Position',[910,659,100,20],'FontSize',10,'BackgroundColor','white','Callback',{@gotobutton_Callback});

htime  = uicontrol('Style','text','String','Time [sec]','Position',[910,635,100,15]);
hsecond  = uicontrol('Style','text','String','0','Position',[910,619,100,15],'BackgroundColor','white');

hday1 = uicontrol ('Style','text','String','D','Position',[910,597,20,15]);
hhour1 = uicontrol ('Style','text','String','H','Position',[937,597,20,15]);
hminute1 =  uicontrol ('Style','text','String','M','Position',[964,597,20,15]);
hsecound1 = uicontrol ('Style','text','String','S','Position',[990,597,20,15]);
hday = uicontrol ('Style','text','Position',[910,581,20,15],'BackgroundColor','white');
hhour = uicontrol ('Style','text','Position',[937,581,20,15],'BackgroundColor','white');
hminute =  uicontrol ('Style','text','Position',[964,581,20,15],'BackgroundColor','white');
hsecound = uicontrol ('Style','text','Position',[990,581,20,15],'BackgroundColor','white');

hltext  = uicontrol('Style','text','String','Window Size [sec]','Position',[910,555,100,20]);
hlength = uicontrol('Style','edit','String','60','Position',[910,544,100,20],'FontSize',10,'Callback',{@gotobutton_Callback},'BackgroundColor','white');

% Bottom row
hPrevious    = uicontrol('Style','pushbutton','String','<   Previous','Position',[400,12,85,27],'Callback',{@Previousbutton_Callback},'BackgroundColor',teal,'ForegroundColor','w');
hnext    = uicontrol('Style','pushbutton','String','Next  >','Position',[585,12,85,27],'Callback',{@nextbutton_Callback},'BackgroundColor','white','BackgroundColor',teal,'ForegroundColor','w');
tostart    = uicontrol('Style','pushbutton','String','< <','Position',[360,12,30,27],'Callback',{@tostartbutton_Callback},'BackgroundColor',teal,'ForegroundColor','w');
toend    = uicontrol('Style','pushbutton','String','> >','Position',[680,12,30,27],'Callback',{@toendbutton_Callback},'BackgroundColor','white','BackgroundColor',teal,'ForegroundColor','w');
%%  axes
% hyaxes = uicontrol('Style','slider','Min',100,'Max',4000,'value',1000,'SliderStep',[0.1 0.2],'Position',[15,300,10,220],'Callback',{@yaxes_Callback});

% hyaxes = uicontrol('Style','slider','Min',1,'Max',4,'value',1.5,'SliderStep',[0.05 0.05],'Position',[15,300,10,220],'Callback',{@yaxes_Callback});
hyaxes = uicontrol('Style','slider','Min',0,'Max',1,'value',0.5,'SliderStep',[0.01 0.01],'Position',[15,300,10,220],'Callback',{@yaxes_Callback});
ha = axes('Units','pixels','Position',[70,300,935,220]);
ylabel ('Amplitude [mV]','color','white','FontWeight','bold');
set (gca,'FontWeight','bold',  'TickDir','in', 'XTick',[],'YColor', 'white','YTick',[],'XColor', 'white');

haF = axes('Units','pixels','Position',[70,175,935,120],'ButtonDownFcn',{@selectfeatures_Callback});%('Position',[70,205,935,80.5]);
set (haF,'XColor', 'white','YColor', 'white','Xlim', [0 60],'YTick',[],'XTick',[]);
ylabel ('Features','color','white','FontWeight','bold');
set (gca,'FontWeight','bold',  'TickDir','in', 'XTick',[],'XColor', 'white','YColor', 'white');
haA = axes('Units','pixels','Position',[70,60,935,110],'FontSize',8);
ylabel ('ANN output','color','white','FontWeight','bold');
xlabel ('Time [sec]','color','white','FontWeight','bold');
set (gca,'FontSize', 15, 'Xlim',[ 0 60],'FontWeight','bold',  'TickDir','in', 'XColor', 'white','YColor', 'white','YTick',[]);

%% COLUMN 5
hannout = uicontrol('Style','checkbox','String','Display ANN Output','Position',[775,675,110,25],'Callback',@plotann_Callback);
hPlotFeat = uicontrol('Style','checkbox','String','Feature Plot','Position',[775,645,110,25],'Callback',@plotfeatures_Callback);
hImfeat = uicontrol('Style','checkbox','String','Feature Image','Position',[775,615,110,25],'Callback',{@plotfeatures_Callback});
hcpower = uicontrol ('Style','checkbox','String','Power Analysis','Position',[775,585,110,25],'Callback',{@plotfeatures_Callback});
hspectrum = uicontrol('Style','checkbox','String','Display Spectrum','Position',[775,555,110,25],'Callback',{@plotfeatures_Callback});
% hfeatselect = uicontrol('Style','togglebutton','String','Select features','Position',[775,610,110,15],'Callback',{@selectfeatures_Callback});

%% MENUS
%%%%%%%%%%%%%%%%%%%%
%%%%%%%%%%%%%%%%%%%%

%% 'Sampling Rate'
hsr = uimenu( 'Label','Sampling Rate',...
    'Tag','prop1');
labels = {'1000Hz','500Hz','200Hz'};
tags = {'F1000','F500','F200'};
callbacks = {@f1000,@f500,@f200,};
hands={};
for idx = 1:length(labels)
    hands{idx}= uimenu('Parent',hsr,...
        'Label',labels{idx},...
        'Callback',callbacks{idx},...
        'Tag',tags{idx});
end
F1=hands{1};
F2=hands{2};
F3=hands{3};
set(F1, 'Checked', 'on');

%% 'No. of features'

hF = uimenu( 'Label','Feature combination',...
    'Tag','prop1');
labels = {'5','all'};
tags = {'F5','F22'};
callbacks = {@f5,@f22};
hands={};
for idx = 1:length(labels)
    hands{idx}= uimenu('Parent',hF,...
        'Label',labels{idx},...
        'Callback',callbacks{idx},...
        'Tag',tags{idx});
end
F5=hands{1};
F22=hands{2};
set(F5, 'Checked', 'on');
%%
% SPECIFY FEATURES

hF = uimenu( 'Label','Features',...
    'Tag','prop1');
labels = {'E','FD','STD','CL','Maxd','Peak','K','AC', 'ZC', 'AI',...
    'MNE','SDNE','KNE','SNE',...
    'SDFFT','KFFT','SFFT', 'MFFT',...
    '3-8','8-12','12-20', '20-40','30-45' , '55-75' , '75-100','30-100'};
% UseFeats=zeros(1,length(labels));
for idx = 1:length(labels)
    Fhands{idx}= uimenu('Parent',hF,...
        'Label',labels{idx},...
        'Callback',@FeatMenu,...
        'Tag',strcat('Fe',num2str(idx)));
end


f5

%% 'Noise Threshold'
NTH = uimenu( 'Label','Noise Threshold',...
    'Tag','prop4');
labels = {'0.6 mV','0.8 mV','1 mV','1.2 mV','1.4mV','1.6mV','Define Other...'};
tags = {'NT1','NT2','NT3','NT4','NT5','NT5','NTother'};
callbacks = {@NTH1,@NTH2,@NTH3,@NTH4,@NTH5,@NTH6,@NTHother};
hands={};
for idx = 1:length(labels)
    hands{idx}= uimenu('Parent',NTH,...
        'Label',labels{idx},...
        'Callback',callbacks{idx},...
        'Tag',tags{idx});
end
NT1=hands{1};
NT2=hands{2};
NT3=hands{3};
NT4=hands{4};
NT5=hands{5};
NT6=hands{6};
NTother=hands{7};
set(NT4, 'Checked', 'on');
%% NETWORK MENU
hnet = uimenu( 'Label','Neural Network',...
    'Tag','prop4');
PrepareNetMenu();
%% Classification  Threshold Menu
classprop=uimenu( 'Label','Classification Settings');

ann = uimenu('Parent',classprop, 'Label','Threshold Classification ',...
    'Tag','prop3', 'Callback',@class_method);
set(ann,'Checked', 'on');
labels = {'1','0.9','0.8','Define Other...'};
tags = {'T1','T2','T3','Tother'};
callbacks = {@TH1,@TH2,@TH3,@THother,};
hands={};
for idx = 1:length(labels)
    hands{idx}= uimenu('Parent',ann,...
        'Label',labels{idx},...
        'Callback',callbacks{idx},...
        'Tag',tags{idx});
end
T1=hands{1};
T2=hands{2};
T3=hands{3};
Tother=hands{4};
set(T1, 'Checked', 'on');


slope = uimenu('Parent',classprop, 'Label','Slope Classification ',...
    'Tag','prop3', 'Callback',@class_method);
labels = {'1','0.9','0.8','Define Other...'};
tags = {'S1','S2','S3','Tother'};
callbacks = {@SlH1,@SlH2,@SlH3,@SlHother,};
hands={};
for idx = 1:length(labels)
    hands{idx}= uimenu('Parent',slope,...
        'Label',labels{idx},...
        'Callback',callbacks{idx},...
        'Tag',tags{idx});
end
Sl1=hands{1};
Sl2=hands{2};
Sl3=hands{3};
Slother=hands{4};
% set(Sl1, 'Checked', 'on');


%%  Duration Menu
hds = uimenu('Label','Duration');

hTl = uimenu( 'Parent',hds, 'Label','Minimal Seizure Duration',...
    'Tag','prop3');
labels = {'10 Sec','8 Sec','6 Sec','4 Sec','2 Sec','Define Other'};
tags = {'S10','S8','S6','D4','S2','Sother'};
callbacks = {@SH10,@SH8,@SH6,@SH4,@SH2,@SHother};
hands={};
for idx = 1:length(labels)
    hands{idx}= uimenu('Parent',hTl,...
        'Label',labels{idx},...
        'Callback',callbacks{idx},...
        'Tag',tags{idx});
end
SO=hands{6};
S2=hands{5};
S4=hands{4};
S6=hands{3};
S8=hands{2};
S10=hands{1};

set(S6, 'Checked', 'on');
%% INTERVAL between seizures
hm = uimenu( 'Parent',hds,'Label','Interval between seizures',...
    'Tag','prop3');
labels = {'1 min','2 min','3 min','5 min'};
tags = {'M1','M2','M3','M4'};
callbacks = {@M11,@M22,@M33,@M44};
hands={};
for idx = 1:length(labels)
    hands{idx}= uimenu('Parent',hm,...
        'Label',labels{idx},...
        'Callback',callbacks{idx},...
        'Tag',tags{idx});
end
M3=hands{3};
M2=hands{2};
M1=hands{1};
M4=hands{4};
set(M1, 'Checked', 'on');
%% Viewing tools menu
ht = uimenu('Label','Viewing Tools');
hands= uimenu('Parent',ht,...
    'Label','Magnifying Glass',...
    'Accelerator','M',...
    'Callback',@MagGlass);
lineplots= uimenu('Parent',ht,...
    'Accelerator','L',...
    'Label','Show Time Marks',...
    'Callback',@showtimemarks);
feet= uimenu('Parent',ht,...
    'Label','Sorry Lyn',...
    'Callback',@LynHasFeet);
txtstream= uimenu('Parent',ht,...
    'Label','Export text file for streaming',...
    'Callback',@txtstreamfile);
nextacc= uimenu('Parent',ht,...
    'Label','Next',...
    'Accelerator','>',...
    'Callback',@nextbutton_Callback);
prevacc= uimenu('Parent',ht,...
    'Label','Previous',...
    'Accelerator','<',...
    'Callback',@Previousbutton_Callback);
%% Desktop mode
hmode = uimenu( 'Label','Desktop mode',...
    'Tag','prop3');
labels = {'Data analysis','Network training'};
tags = {'m1','m2'};
callbacks = {@mm1,@mm2};
hands={};
for idx = 1:length(labels)
    hands{idx}= uimenu('Parent',hmode,...
        'Label',labels{idx},...
        'Callback',callbacks{idx},...
        'Tag',tags{idx});
end
m1=hands{1};
m2=hands{2};
set(m1, 'Checked', 'on');

    function mm1(source,eventdata,handle)
        set(gcbo, 'Checked', 'on');
        set(m2, 'Checked', 'off');
        set(hloadpanel,'Visible','on');
        set(htrainpanel,'Visible','off');
    end
    function  mm2(source,eventdata,handle)
        set(gcbo, 'Checked', 'on');
        set(m1, 'Checked', 'off');
        set(hloadpanel,'Visible','off');
        set(htrainpanel,'Visible','on');
    end
%%  Duration Menu
had = uimenu('Label','Advanced');

hTl = uimenu( 'Parent',had, 'Label','Filter dat file',...
    'Tag','prop3');
labels = {'block <2','block >100','block >45','Go'};
tags = {'b2','b100','b45','g'};
callbacks = {@fil,@fil,@fil,@fil};
hands={};
for idx = 1:length(labels)
    hands{idx}= uimenu('Parent',hTl,...
        'Label',labels{idx},...
        'Callback',callbacks{idx},...
        'Tag',tags{idx});
end
b=hands;
    function  fil(source,eventdata,handle)

        if get(gcbo,'Position')==1 || get(gcbo,'Position')==2 || get(gcbo,'Position')==3
            if strcmp(get(gcbo,'Checked'),'on')
                set(gcbo, 'Checked', 'off');
            else
                set(gcbo, 'Checked', 'on');
            end
        else
            datfile=get(hraw,'String');
            if strcmp(datfile(1:4), 'File')
                msgbox('no dat was selected');
                return
            else


                TargetDat=datfile;

                LP=[];
                HP=[];
                if strcmp(get(b{1},'Checked'),'on')
                    TargetDat=[TargetDat(1:end-4) '_e2.dat'];
                    %                     a=load('HP_fs1000_fc2_order200.mat');
                    %                     HP=a.HP_fs1000_fc2_order200;
                    a=load('HP_fs1000_fc2_order500.mat');
                    HP=a.HP_fs1000_fc2_order500;
                end
                if strcmp(get(b{2},'Checked'),'on')
                    TargetDat=[TargetDat(1:end-4) '_e100.dat'];
                    a=load('LP_fs1000_fc100_order200.mat');
                    LP=a.LP_fs1000_fc100_order200;

                end
                if strcmp(get(b{3},'Checked'),'on')
                    TargetDat=[TargetDat(1:end-4) '_e45.dat'];
                    a=load('LP_fs1000_fc45_ordr200.mat');
                    LP=a.LP_fs1000_fc45_ordr200;

                end


                fidr=fopen(datfile,'r');
                fidw=fopen(TargetDat,'w');
                fseek(fidr,0,'eof');
                place = ftell(fidr);
                fclose(fidr);
                %                 length_of_file_in_h = ceil(place/(4*1000*3600));
                length_of_file_in_m = ceil(place/(4*1000*60));

                fidr=fopen( datfile,'r');

                pl= msgbox('I be  filtering your shit');


                for i=1: length_of_file_in_m
                    data = fread (fidr,[60*1000],'float32');

                    %                     noise=(data==100);
                    %                     data(noise)=nan;
                    %                     data = data-nanmean (data);
                    %                     data(noise)=0;
                    %                     x=find(data==100);
                    %                     xi=find(data~=100);
                    %                     datae=data;
                    %                     datae(x)=[];
                    %
                    %                     datai = interp1(xi,datae,x);
                    %                     data(x)=datai;
                    %                     x=find(data==100);
                    %                    data(x)=nan;

                    %                     datai = interp1(xi,datae,x);
                    %                     data(x)=datai;
                    %                     clear datai datae xi x



                    if HP
                        data=filtfilt( HP,1,data);% hpass of 2 hz
                    end
                    if LP
                        data=filtfilt( LP,1,data);% hpass of 2 hz
                    end
                    %                     data(noise)=100;

                    fwrite(fidw,data,'float32' );
                    %                     return
                end
                fclose(fidw);
                pl= msgbox('I aint filtering no mo');
                %                          set(hraw,'String',TargetDat);

            end
        end
    end
%% NORMALIZE UNITS
set([hloadpanel,htrainpanel,...
    hplottable, htimepoints_table,hselectanimal_table,...
    hremoverows_button,hautoselectnormalizationquiet_checkbox,hsaveanimal_button,...
    hselecttraintype_popup,hnumberofsegments_text,hnumberofsegments_edit,...
    hlengthofsegments_text ,hlengthofsegments_edit,htrain_button,...
    htable, tostart, toend, hyaxes, ha ,haF, haA ,f , hload , hraw , hlistyn ,...
    hsavedir , hdir, hfeature , hSSbutton, hQbutton, hQuiet , hclassify,...
    hloadstarts, hstarts , hsbutton  , hgbutton , hgoto , hPrevious , hnext ,...
    hltext , hlength , htime , hsecond ,hday , hhour , hminute , hsecond , hday ,...
    hadd,hadl,hhour ,dynamicQbutton, hsecound , hday1 , hhour1 , hminute1 , hsecound1 ,hannout , hPlotFeat , hcpower ,hspectrum , hImfeat],...
    'Units','normalized');
uistack(haF,'top');
%%
global p_box h_box filter_mark B length_of_window  A FilterOrder

% s1 = 0.5;
length_of_window = 30;
A = [  0 0 1 1 ];%high pass filter%
FilterOrder = 200;%dont know what it means maybe the stepnes of the cutoff%
B = firls(FilterOrder,[0 0.003 0.004 1],A);
p_box = 0;
h_box = 0;


    function select_Callback(source,eventdata)


        if ~isempty(eventdata.Indices)&&~strcmp(get(hraw,'String'),'File Name (.dat) ')
            if (eventdata.Indices(1))
                bata=get(htable,'Data');
                second=bata(eventdata.Indices(1));
                set(hgoto,'String',second);
                gotocenter_Callback
            end
        end
    end
    function loadbutton_Callback(source,eventdata)
        global chan fid1
        [FileName,PathName] = uigetfile2('*.dat;*.txt','Select file');

        if (FileName==0)
            return;
        end
        loadraw(FileName,PathName);
    end

    function loadraw(FileName,PathName)
        global fid xaxes data_samp rate l data time_s chan dirct lims ;
        dirct = fullfile(PathName,FileName);
        yaxes_Callback

        if  (strcmp('txt', FileName(end-2:end)));
            dirct=txt_file(dirct,PathName,FileName);
        end
        if  (strcmp('mat', FileName(end-2:end)));
            dirct=mat_file(dirct,PathName,FileName);
        end
        namestr=dirct;
        namestr(strfind(namestr, ' '))='_';
        set(hraw,'String',namestr);%,'HorizontalAlignment','left');

        if isempty(rate)
            rate=1000;
        end
        l = str2double( get (hlength,'String'));
        data_samp = rate*l;
        fid = fopen (dirct,'r');
        if (fid == (-1))
            errordlg('Can not open file')
        else
            data = fread (fid,[data_samp],'float32');
            xaxes = (0:data_samp-1) / rate;
            time_s=0;
            [days,hours,minutes,secunds]= convert_to_date (time_s);
            set (hday,'String',days);
            set (hhour,'String',hours);
            set (hminute,'String',minutes);
            set (hsecound,'String',secunds);
            set(hsecond,'string',time_s);
            set(gcf,'CurrentAxes',ha);

            %             lims=[ -min(max(abs(data)),5) min(max(abs(data)),5)];
            lims=[ -0.3 0.3];

            plot_rawdata( data,xaxes,rate,lims)
            set(haA,'xlim',[ 0  l]);
        end
        if get(hannout,'value');plotann_Callback;end
        if get(hPlotFeat,'value')||get(hcpower,'value')||get(hspectrum,'value');plotfeatures_Callback;end
        if get(hImfeat,'value');plotfeatures_Callback;end
        set(gcbo,'enable','off');set(gcbo,'enable','on')%% DELETE ALL WHEN CLOSING NVISION
        clear fid xaxes data_samp rate l data time_s strings tags strl p j enable g jk
    end
    function dirbutton_Callback(source,eventdata)
        PathName = uigetdir2;
        if PathName==0;
            return;
        end
        set(hdir,'String',PathName);
    end;



    function featurebutton_Callback(hObject, eventdata, handles)
        global rate threshold numberfeatures Qdata dirct UseFeats;
        file_name = dirct;
        save_path = get(hdir,'String');

        fidf = fopen (file_name,'r');
        fseek(fidf,0,'eof');
        place = ftell(fidf);
        fclose(fidf);
        length_of_file_in_hours = ceil(place/(4*rate*3600));
        %open file for analsys
        fidf = fopen (file_name,'r');
        LP=[];
        switch rate
            case 200
                a=load('HP_fs200_fc2_order200.mat');
                HP=a.HP_fs200_fc2_order200;
            case 500
                a=load('HP_fs500_fc2_order400.mat');
                HP=a.HP_fs500_fc2_order400;
            case 1000
                a=load('LP_fs1000_fc250_order600.mat');
                LP=a.LP_fs1000_fc250_order600;
                a=load('HP_fs500_fc2_order400.mat');
                HP=a.HP_fs500_fc2_order400;
        end

        %%         Calculate threshold
        if isempty(threshold)
            threshold=1.2;%  h=  msgbox('Threshold was set by default to 1.2mV','Threshold settings');
        end
        %%  Calculate features
        for hour = 1:length_of_file_in_hours
            [dataf] = fread (fidf,3600*rate,'float32');
            wdata = winnyAll (dataf,rate,threshold,HP,LP,UseFeats);
            savename = [int2str(hour) 'wdata.csv'];
            csvwrite([save_path '\' savename],wdata);
        end;
        fclose(fidf);
        msgbox(['Results were saved in:'  save_path],'Done!','help');
    end;
    %%

    function quietbutton_Callback(hObject, eventdata, handles)
        % hObject    handle to quiet (see GCBO)
        % eventdata  reserved - to be defined in a future version of MATLAB
        % handles    structure with handles and user data (see GUIDATA)
        [FileName,PathName] = uigetfile2('*.mat','Select the M-file');
        dirctq = [PathName FileName];
        if (FileName==0)
            return;
        end
        set(hQuiet,'String',dirctq);
    end;
    %% CLASSIFICATION OF FEATURES
    function classifybutton_Callback(hObject, eventdata, handles)
        global  slopetivity interval output Q Qdata rate all  threshold sensitivity allfeat animal ...,
            netrout duration AllNetNames UseNets NetLegNames PlotNets NetGroupNames UseFeats  all_firstmap allfeat_nomap;
        try



            all={};
            Q=[];
            startsSec=[];
            lengthwin=[];
            dirctq=(get(hQuiet,'String'));
            %% QUIET NORMALIZATION
            if   isempty(Qdata )
                if  strcmp(dirctq, 'File Name' )
                    errordlg('Choose or upload quiet segment')
                    return;
                else
                    a=load(dirctq);% load quiet hour
                    if isfield(a,'mapmax')
                        load('Qfile.mat')
                        Q.xmax=str2num(a.mapmax);
                        Q.xmin=str2num(a.mapmin);
                    else
                        Qdata=a.data;
                    end
                end
            else
                startsSec=get(hsecond,'string');
                lengthwin=get(hlength,'string');
            end
            clear a
            %%

            %         save (direct,'xaxes','data','time_s','rate');
            if isempty(rate)
                rate=1000;end

            if isempty(sensitivity)
                sensitivity=1;end

            %         annhold = str2double(get(hdetect,'String'));;
            if isempty (threshold)
                threshold=1.2;
            end

            if ~sum(cell2mat(UseNets))
                ind=find(ismember(NetGroupNames, 'net_219.mat')==1);
                UseNets{ind}=1;
            end
            if isempty(interval)
                interval=1;end
            if isempty (duration)
                duration=6;
            end
            if isempty(NetLegNames)
                NetLegNames={} ;
            end

            %% file name
            PathName = (get(hdir,'String'));
            if strcmp(PathName,'Folder Name')
                return;
            end



            %% LOAD FILTERS
            LP=[];
            switch rate
                case 200
                    a=load('HP_fs200_fc2_order200.mat');
                    HP=a.HP_fs200_fc2_order200;
                case 500
                    a=load('HP_fs500_fc2_order400.mat');
                    HP=a.HP_fs500_fc2_order400;
                case 1000
                    a=load('LP_fs1000_fc250_order600.mat');
                    LP=a.LP_fs1000_fc250_order600;
                    a=load('HP_fs500_fc2_order400.mat');
                    HP=a.HP_fs500_fc2_order400;
            end
            %%
            %         agg=get(haggregate,'value');
            allfeat=[];
            all_firstmap=[];
            allfeat_nomap=[];
            NetLegNames={};
            Nets={};
            Maps={};
            used=find(UseFeats);
            need=[ 1 3 4 21 22];
            [c, spots, ib] = intersect(used,need);
            clear used need c ib
            if length(spots)~=5
                msgbox('can not classify without the right features');
                return
            end
            %% WHICH NETS TO USE
            for n=1:length(AllNetNames)
                alreadyloadedset=false;
                for i=1:length(UseNets{n})

                    if UseNets{n}(i,1)
                        if ~alreadyloadedset
                            one_net_set=load([NetFolder NetGroupNames{n}],'nets');
                            one_net_set=one_net_set.nets;
                        end
                        Nets=[Nets one_net_set(i)];

                        if ~alreadyloadedset
                            one_map_set=load([NetFolder NetGroupNames{n}],'Secondmapsettings');
                            one_map_set=one_map_set.Secondmapsettings;

                        end
                        Maps=[Maps one_map_set(i)];

                        if ~alreadyloadedset
                            one_legend_name_set = load([NetFolder NetGroupNames{n}],'netnames');
                            one_legend_name_set = one_legend_name_set.netnames;
                            alreadyloadedset=true;
                        end
                        NetLegNames=[NetLegNames one_legend_name_set{i}];
                    end
                end
            end

            PlotNets=num2cell(logical(ones(1,length(Nets))));


            %% FEATURE CLASSIFICATION
            if isempty(Q)
                if size(Qdata,2)==1
                    Qdata=Qdata';
                end
                wdata = winnyAll(Qdata,rate,threshold,HP,LP,UseFeats);
                [mapped Q]=mapminmax(wdata');
            end

            wdataFOLDER=[PathName '\'];
            L=length(dir(wdataFOLDER))-2;
            %RUN ON ALL NETS
            for n=1:length(Nets)
                allthisnet=[];
                for i=1:L

                    clear('firstmap','secmap','yy');
                    filetoload= [wdataFOLDER num2str(i)  'wdata.csv'];
                    if exist(filetoload,'file')

                        newW= load( filetoload)';%load w data
                        allfeat_nomap=[allfeat_nomap newW];

                        ind=find(isnan(newW(1,:)) );% remove nans
                        restind=setdiff(1:size(newW,2),ind);
                        newW(:,ind)=[];
                        firstmap= mapminmax('apply' ,newW, Q);  %ADJUST MAPPING STRUCTURE
                        S= firstmap(  spots   ,:);
                        if ~isfield(Maps{n},'no_change')
                            Maps{n}.no_change=true;
                        end
                        secmap= mapminmaxold('apply' ,S, Maps{n});

                        yy= sim(Nets{n},secmap);
                        OUTPUT=nan(1,3600);
                        OUTPUT(restind)=yy; %preserving time correlation
                        allthisnet=[allthisnet OUTPUT];

                        wdata_secmap=nan(5,3600);
                        wdata_secmap(:,restind)=secmap;
                        allfeat=[allfeat wdata_secmap];

                        wdata_firstmap=nan(sum(UseFeats),3600);
                        wdata_firstmap(:,restind)=firstmap;
                        all_firstmap=[all_firstmap  wdata_firstmap];

                    end
                end; %main loop
                all=[all allthisnet];
            end


            %%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%
            %%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%
            ClassificationMode=[0 0];

            if strcmp(get(ann,'Checked'),'on')
                ClassificationMode(1)=1;
            end
            if strcmp(get(slope,'Checked'),'on')
                ClassificationMode(2)=1;
            end

            ClassificationMode(2)=0;    % we never use this classification mode.

            if ClassificationMode(2)==1
                disp('using slopes - this takes a long time');
            end

            %% THE SEIZURE HAUNT
            %         starts=find_seizures(all,sensitivity,duration,interval,ClassificationMode);
            [starts durations]=find_seizures(all,sensitivity,duration,interval,ClassificationMode); % durations added by J. Kukurin


            %% THE SEIZURE HAUNT
            Feature_Folder=get(hdir,'String');
            timeQ=get(hgoto,'String');
            lengthQ=get(hlength,'String');


            if ~isempty(cell2mat(starts))
                a=num2cell(starts{1}');
                d=num2cell(durations');

                b=get(htable,'Data');
                b=b(1,:);

                b(1:length(a),1)={[]};
                b(1:length(a),1)=a;
                b(1:size(d,1),2)=d(:,1);
                b(1:size(d,1),3)=d(:,2);
                b(1:size(d,1),4)=d(:,3);
                b(1:size(d,1),5)=d(:,4);
                b(1:size(d,1),6)=d(:,5);
                b(1:size(d,1),7)=d(:,6);
                b(1:size(d,1),8)=d(:,7);
                columnformat = {'char' , 'char', 'char', 'char', 'char', 'char', 'char', 'char',{' ' 'Log' 'Seizure' 'InterIctal' 'Noise'}, 'logical'};
                columneditable =  [false false false false false false false false true true ];
                set(htable,'Data',b,...
                    'ColumnFormat', columnformat,...
                    'ColumnEditable', columneditable)

                UpdatePlotNetsTable();

                sesLength=length(starts{1,1}');
                ses=starts{1,1}';
            else
                ses='0';
                sesLength=0;
            end
            %NAME OUTPUT FILE
            if ~ strcmp(dirctq, 'File Name' )
                filename= ['\nth' num2str(threshold) '_ann' num2str(sensitivity) '_du' num2str(duration) '_loadedQ' '_detected_' num2str(sesLength)];
                output = [PathName filename ];
            else
                filename=[  '\nth_' num2str(threshold) '_ann_' num2str(sensitivity) '_du_' num2str(duration) '_int_'  num2str(interval) '_st_'  startsSec '_' lengthwin '_detected_' num2str(sesLength) ];
                output = [PathName filename];
            end
            output(output=='.')=[];
            output=[output '.mat'];
            set(hstarts,'String',filename);

            save([output],'Q','all','starts','threshold','allfeat','Nets','NetLegNames','sensitivity',...
                'timeQ','lengthQ','Feature_Folder','duration', 'interval', 'allfeat_nomap','UseFeats','all_firstmap','ses','b');
            msgbox(['Results were saved in:'  output],'Done!','help');
        catch
            msgbox('An error occurred.');
        end



    end


    function UpdatePlotNetsTable()
        global NetLegNames PlotNets
        new_data=[{NetLegNames{:}}' {PlotNets{:}}'];
        set(hplottable,'Data',new_data);
    end
    function EditPlotTable_Callback(source,eventdata)
        global PlotNets;
        index=eventdata.Indices;
        if index(2)==3 % show event timelines
            DrawSeizureAndLog()
        else %plot network output
            PlotNets{index(1)}=eventdata.NewData;
            plotann_Callback()
        end
    end


    function listybutton_Callback(hObject, eventdata, handles)
        starts = get(hlisty,'String');
        index = get(hlisty,'Value');
        second=(starts{index});
        set(hgoto,'String',second);
        gotocenter_Callback
    end
    function Coordinates_Callback(hObject, eventdata, handles)
        global output allfeat all PlotNets NetLegNames rate sensitivity all_firstmap allfeat_nomap;


        %         if ~isempty(all)&&  strcmp(class(all),'double');
        %             all=mat2cell(all);end
        if isempty(all)
            all={}; %Tomer
        end
        [FileName,PathName] = uigetfile2({'*.mat';'*.xls';'*.xlsx' ;'*.csv'},'Select file with coordinate vector');
        if (FileName==0)
            return;
        end
        output = [PathName FileName];
        m = findstr('mat', FileName);
        x = findstr('xls', FileName);
        c = findstr('csv', FileName);
        if m
            m=load(output);
            if isfield(m, 'starts')
                starts=m.starts;
            else
                starts=0;
            end
            if isfield(m, 'all')
                all= [ m.all]; %Tomer: Changed to cell
                allfeat=m.allfeat;
            end
            if isfield(m, 'all_firstmap')
                all_firstmap=m.all_firstmap;
                allfeat_nomap=m.allfeat_nomap;
            end
            if isfield(m,'NetLegNames')
                NetLegNames = [NetLegNames m.NetLegNames];
                PlotNets=vertcat(PlotNets,num2cell(logical(ones(length(m.all),1))));
            else
                NetLegNames={'net219'};
                PlotNets={logical(1)};
            end
            UpdatePlotNetsTable();

        end
        %Tomer: Seizure Starts temporarily disabled.
        %         if x
        %             starts=xlsread(dirct);
        %         end;
        %         if c
        %             starts=csvread(dirct);
        %         end;
        %
        set(hstarts,'String',FileName(1:end-4));

        if strcmp(class(starts),'cell')
            starts=cell2mat(starts);end
        if size(starts,2)>1;
            starts=starts';
        end
        a=num2cell(starts);
        %         set(hlisty,'String',a);
        if ~isempty(a)
            b=get(htable,'Data');
            b=b(1,:);
            b(1:length(a),1)=a;

            if isfield(m, 'sensitivity')
                sensitivity=m.sensitivity;
            end
            if isfield(m, 'b')
                b=m.b;
            else
                b=get(htable,'Data');
                b(1:length(a),1)=a;

                if isfield(m, 'startdates')
                    set( htable,    'ColumnName',{'Sec','Time','Class',''},...
                        'ColumnWidth', { 50  'auto' 'auto' 20});
                    b(1:length(a),2)=m.startdates';
                    if isfield(m, 'tags')
                        b(1:length(a),3)=m.tags';
                    else
                        b(1:length(a),3)={' '};
                    end

                    b(1:length(a),4)={false};
                    columnformat = {'char' , 'char', {' ' 'Log' 'Seizure' 'InterIctal' 'Noise'}, 'logical'};
                    columneditable =  [false false true true ];
                else
                    b(1:length(a),2)={' '};
                    if isfield(m, 'tags')
                        tags=m.tags;
                        b(1:length(a),3)=tags';
                    else
                        b(1:length(a),3)={' '};
                    end
                    columnformat = {'char' , 'char', {' ' 'Log' 'Seizure' 'InterIctal' 'Noise'}, 'logical'};
                    columneditable =  [false false true true ];
                end
                % % % columnformat = {'numeric', 'char', 'logical'};
                % % % columneditable =  [false false true ];
                b(:,4)={false};
            end
            columnformat = {'char', 'char', 'char', 'char', 'char', 'char', 'char', 'char', {' ' 'Log' 'Seizure' 'InterIctal' 'Noise'}, 'logical'};
            columneditable =  [false false false false false false false false true true ];
            if size(b,2)==4
                % new fields have been added (window of seizure events,
                % number of seconds within window exceeding threshold, and
                % percentage of the above)
                insertedColumns =  cell((size(m.b,1)),6);
                test =m.b(:,1:2);
                test2 =m.b(:,3:end);
                tableData = [test insertedColumns test2];

            else
                tableData=b;
            end

            set(htable,'Data',tableData,...
                'ColumnFormat', columnformat,...
                'ColumnEditable', columneditable)
        end

    end
    function nextbutton_Callback(source,eventdata)
        global fid xaxes data_samp l data rate time_s ;
        time_s = time_s + l;
        set(hgoto,'String', time_s);
        gotobutton_Callback
    end
    function Previousbutton_Callback (source,eventdata)
        global fid xaxes data_samp l data rate time_s;
        time_s = time_s - l;
        if (time_s <0); time_s=0;end;
        set(hgoto,'String', time_s);
        gotobutton_Callback
    end
    function tostartbutton_Callback(hObject, eventdata, handles)
        set(hgoto,'String',0);
        gotobutton_Callback
    end
    function toendbutton_Callback(hObject, eventdata, handles)
        global rate dirct
        l = str2double( get (hlength,'String'))
        file_name = dirct;
        %         file_name = get(hraw,'String')
        fidf = fopen (file_name,'r')
        fseek(fidf,0,'eof')
        place = ftell(fidf)
        fclose(fidf)
        new_time=place/(rate*4)-l-1
        set(hgoto,'String',  new_time)
        gotobutton_Callback
    end



    function resetbutton_Callback(source,eventdata)
        global  fid xaxes data_samp rate l data time_s lims ;
        %temp = xaxes (1);

        set(gcf,'CurrentAxes',ha);

        if data_samp
            move_samp = -1 * data_samp * 4;
            fseek (fid,move_samp,'cof');
            %             rate = str2double( get (hrate,'String'));
            l = str2double( get (hlength,'String'));
            data_samp = rate*l;
            xaxes = ((0:data_samp-1) / rate);% + temp;
            data = fread (fid,[data_samp],'float32');
            plot_rawdata( data,xaxes,rate,lims)
            set(haA,'xlim',[ 0  l]);
            if get(hannout,'value');plotann_Callback;end
            if get(hPlotFeat,'value')||get(hcpower,'value')||get(hspectrum,'value');plotfeatures_Callback;end
            if get(hImfeat,'value');plotfeatures_Callback;end
            set(haA,'xlim',[ 0  l]);
            clear  fid xaxes data_samp rate l data time_s;
        end
        DrawSeizureAndQuietMarks
        DrawSeizureAndLog
        set(gcf,'CurrentAxes',haF);
        set(gcf,'ButtonDownFcn',{@selectfeatures_Callback});

    end


    function gotocenter_Callback (source,eventdata)
        global fid xaxes data_samp rate data time_s lims ;
        set(gcf,'CurrentAxes',ha);
        newtime = str2double( get (hgoto,'String'));
        l = str2double( get (hlength,'String'));
        newtime=newtime-l/2;

        if (newtime <0); newtime=0;end;  %Tomer
        set (hgoto,'String',num2str(newtime));
        move_samp =   newtime * 4 * rate;
        a = fseek (fid,move_samp,'bof');
        if (a == (-1))
            errordlg('no such time')
        else
            %xaxes = ((0:data_samp-1) / rate) + newtime;
            data = fread (fid,[data_samp],'float32');
            %             if filter_mark == 1
            %                 data = Filter_fun (data,B);
            %             end
            set(gcf,'CurrentAxes',ha);
            plot_rawdata( data,xaxes,rate,lims)
            set(gcf,'CurrentAxes',haF);
            k=5;
            plot (data(end/2-rate*k+1:end/2+rate*k),'Color',[0.5,0,0.5]');
            axis tight;
            ylim (lims);
            ylabel ('Amplitude [mV]','color','white');
            set (gca,'XColor', 'white','YColor', 'white','XTick',[]);
            set(haA,'xlim',[ 0  l]);
            time_s = newtime;
            [days,hours,minutes,secunds]= convert_to_date (time_s);
            set (hday,'String',days);
            set (hhour,'String',hours);
            set (hminute,'String',minutes);
            set (hsecound,'String',secunds);
            set(hsecond,'string',time_s);
            set(haA,'xlim',[ 0  l]);
        end
        if get(hannout,'value');plotann_Callback;end
        if get(hPlotFeat,'value')||get(hcpower,'value')||get(hspectrum,'value');plotfeatures_Callback;end
        if get(hImfeat,'value');plotfeatures_Callback;end
        clear fid xaxes data_samp rate data time_s;
        DrawSeizureAndLog()
        set(gcf,'CurrentAxes',haF);
        set(gcf,'ButtonDownFcn',{@selectfeatures_Callback});

    end
    function gotobutton_Callback (source,eventdata)%goes to begining of next second
        global fid xaxes l data_samp rate data time_s dirct lims ;
        if ~ isempty(data);
            l = str2double( get (hlength,'String'));
            data_samp=l*rate;
            set(gcf,'CurrentAxes',ha);
            newtime = str2double( get (hgoto,'String'));
            %         l = str2double( get (hlength,'String'));
            %         newtime=newtime-l/2;

            file_name = dirct;
            %             file_name = get(hraw,'String');
            fidf = fopen (file_name,'r');
            fseek(fidf,0,'eof');
            place = ftell(fidf);
            fclose(fidf);
            length_of_file_in_sec = ceil(place/(4*rate));
            %         if (a == (-1))
            %             errordlg('no such time')
            %             if newtime>length_of_file_in_sec-l     ||       newtime<0;
            %                 errordlg('Window exceeds dara dimensions');
            %             else
            if (newtime <=0); newtime=1;end;
            if newtime>=length_of_file_in_sec-l;newtime=length_of_file_in_sec-l;end
            move_samp =   newtime * 4 * rate;
            a = fseek (fid,move_samp,'bof');
            xaxes=0:l-1;
            %xaxes = ((0:data_samp-1) / rate) + newtime;
            data = fread (fid,[data_samp],'float32');
            %                 if filter_mark == 1
            %                     data = Filter_fun (data,B);
            %                 end
            plot_rawdata( data,xaxes,rate,lims)
            set(gcf,'CurrentAxes',haF);
            k=5;
            plot (data(end/2-rate*k+1:end/2+rate*k),'Color',[0.5,0,0.5]');
            axis tight;
            ylim (lims);
            ylabel ('Amplitude [mV]','color','white');
            set (gca,'XColor', 'white','YColor', 'white','XTick',[]);
            %             set(haF,'xlim',[ 0  2*k*rate]);

            set(haA,'xlim',[ 0  l]);
            %                 set(ha,'ylim',[ -s1  s1]);
            time_s = newtime;
            [days,hours,minutes,secunds]= convert_to_date (time_s);
            set (hday,'String',days);
            set (hhour,'String',hours);
            set (hminute,'String',minutes);
            set (hsecound,'String',secunds);
            set(hsecond,'string',time_s);
            %TOMER:
            DrawSeizureAndQuietMarks();

            set(gcf,'CurrentAxes',haF);
            % % %             set (gca,'XColor', 'white');

            if get(hannout,'value');plotann_Callback;end
            if get(hImfeat,'value')||get(hPlotFeat,'value')||get(hcpower,'value')||get(hspectrum,'value');plotfeatures_Callback;end
            %             if get(hImfeat,'value');plotfeatures_Callback;end
            clear fid xaxes data_samp rate data time_s;
        end
        DrawSeizureAndLog()
        set(gcf,'CurrentAxes',haF);
        set(gca,'ButtonDownFcn',{@selectfeatures_Callback});

    end


    function DrawSeizureAndLog ()
        global rate showmarks lims
        if showmarks
            % CHECK IF NET DRAW SELECTED
            set(gcf,'CurrentAxes',ha);
            xl= get(ha,'XLim');

            start_time= str2num(get(hsecond,'string'));

            events=get(htable,'Data');
            if exist('events')
                times=events(:,1);
                comments=events(:,3);
                events=cell2mat(events(:,1));
                xxx=(events-start_time)*rate;
                comment=comments(find(xl(1)<xxx &xxx<xl(2)));
                times=times(find(xl(1)<xxx &xxx<xl(2)));
                xxx=xxx(find(xl(1)<xxx & xxx<xl(2)));
                s1=max(get(gca,'Ylim'));
                for k=1:length(xxx)
                    x=xxx(k);
                    line([x x],lims,'color',[ 0 0.5 0.5],'LineStyle','-','LineWidth',1.5);

                    text(x*1.01, 0.7*s1, [ times(k) '  ' comment(k)])%,'BackgroundColor',[ 0    0.5000    0.5000], 'ForegroundColor','white');

                end
            end

        end
    end
    function DrawSeizureAndQuietMarks ()
        global xaxes rate
        set(gcf,'CurrentAxes',ha);
        start_time= str2num(get(hsecond,'string'));
        end_time = start_time +length(xaxes);
        for i=1:2
            if i==1
                c='r';
            elseif i==2
                c='g';
            end
            [len,~]=size(time_points{i});
            for n=1:len
                if (time_points{i}(n,1)>=start_time)&&(time_points{i}(n,1)<=end_time)
                    x=(time_points{i}(n,1)-start_time)*rate;
                    line([x x],[-20 20],'color',c,'LineStyle','--');
                end
                if (time_points{i}(n,2)>=start_time)&&(time_points{i}(n,2)<=end_time)
                    x=(time_points{i}(n,2)-start_time)*rate;
                    line([x x],[-20 20],'color',c,'LineStyle','--');
                end
            end
        end
    end
    function savebutton_Callback (source,eventdata)
        global  xaxes rate data time_s all allfeat Q all_firstmap allfeat_nomap;
        [file,path] = uiputfile2('*.mat','Save Workspace As');
        direct = [path file];
        if ~( path); return;
        else
            l = str2double( get (hlength,'String'));
            ann=[];
            feat0=[];
            feat1=[];
            feat2=[];
            powers=[];
            if exist ('all')&&~isempty(all)
                if strcmp(class(all),'cell'); all=cell2mat(all);end
                ann=all(time_s+1:time_s+l);end
            if exist('allfeat')&&~isempty(allfeat)
                feat2= allfeat(:,time_s+1:time_s+l);end
            if exist('all_firstmap')&&~isempty(all_firstmap)
                feat1= all_firstmap(:,time_s+1:time_s+l);end
            if exist('allfeat_nomap')&&~isempty(allfeat_nomap)
                feat0= allfeat_nomap(:,time_s+1:time_s+l);end


            [pxxch1, fvch1] = pwelch( data,hamming(rate*length_of_window), rate*length_of_window*0.5, 2048, rate);
            powers=  [pxxch1, fvch1];
            [s,f,t]=spectrogram(data,rate*2,rate,[],rate);
            b=get(htable,'Data');


            save (direct,'b','xaxes','data','time_s','rate','feat0','feat1','feat2','ann','powers','s','f','t','Q');

            msgbox('The current data was saved','Done!','help');
            %             clear xaxes rate data time_s powers pxxch1  fvch1 ann feat s f t;
        end
    end
    function Qsavebutton_Callback (source,eventdata)
        global  xaxes rate data time_s Qdata;
        Qdata=data;
        msgbox('Features will be normalized to this segment','Done!','help');
        clear xaxes rate data time_s Qdata;
    end
    function window_Callback (source,eventdata)
        length_of_window = str2double (get (hgoto,'String'));
    end
    function yaxes_Callback (source,eventdata)
        global lims lastval
        set(gcf,'CurrentAxes',ha);
        lims=get(ha,'YLim');
        if isempty(lastval)
            lastval=0.5;
        end
        if get(hyaxes,'Value')>lastval
            lims=lims*0.9;
        else
            lims=lims*1.1;
        end
        set(ha,'YLim',lims);
        lastval=get(hyaxes,'Value');
    end

movegui(f,'center')
set(f,'Visible','on');

    function plotann_Callback (source,eventdata)
        global fid xaxes data_samp sensitivity rate data time_s all NetNames UseNets NetLegNames PlotNets  ;
        LegNamesToBeUsed={};

        set(gcf,'CurrentAxes',haA);
        cla reset;
        if get(hannout,'value');


            l = str2double( get (hlength,'String'));


            %         haaa = axes('Units','pixels','Position',[80,50,800,70],'Visible','off');
            %         hold on
            %,'color',[ 0 .3 .3]
            % if ~iscell(all); all={all}; end;
            x=[[0.001  :  l-0.001] [1-0.001  :  l-0.001] ];
            x=sort(x);
            if strcmp(class(all),'double')
                all={all};end
            for n=1:length(all) %Tomer: For command

                if PlotNets{n}
                    % if time_s+l>length(all)
                    % toendbutton_Callback
                    % end
                    if time_s+l>length(all{n});all{n}(time_s+l)=nan;end
                    A=all{n}(time_s+1:time_s+l);
                    y=reshape([ A ; A],[1 l*2]);

                    LegNamesToBeUsed=[LegNamesToBeUsed NetLegNames{n}];
                    axis tight

                    plot(x,y,'LineWidth',1.5);
                    set(haA,'xlim',[0 l]);
                end

                hold all;
            end


            %             legnames={};

            %             for n=1:length(NetNames)
            %                if UseNets{n}
            %                    legnames=[legnames NetNames{n}];
            %                end
            %
            %             end
            %
            %             leg=legend(legnames);
            if isempty (sensitivity) sensitivity=1;end

            Ll=line([0 l],[-1 -1],'color','k','LineStyle','--');
            L2=line([0 l],[sensitivity sensitivity],'color','k','LineStyle','--' );

            L3=line([0 l],[1 1],'color','k','LineStyle','-' );
            hold off
            ylabel ('ANN output','color','white','FontWeight','normal');
            xlabel ('Time [sec]','color','white','FontWeight','bold');

            set (gca,'XColor', 'white','YColor', 'white','ylim',[ -1.5 2.5]);


            leg=legend(LegNamesToBeUsed);

            set(leg, 'orientation','horizontal','location','North', 'Box', 'off','TextColor','k');

        else
            cla
        end
    end


    function plotfeatures_Callback (source,eventdata)
        global currentcolors fid xaxes data_samp rate data time_s  allfeat

        load('cMAP','mycmap');
        set(gcf,'CurrentAxes',haF);
        l = str2double( get (hlength,'String'));
        plotmode='reset';
        if get(hspectrum,'Value')
            plotmode='spectrumplot';
            set(hcpower,'Value',0);
            set(hImfeat,'Value',0);
            set(hPlotFeat,'Value',0);
        end
        if get(hcpower,'Value')
            plotmode='fftplot';
            set(hspectrum,'Value',0);
            set(hImfeat,'Value',0);
            set(hPlotFeat,'Value',0);
        end
        if get(hImfeat,'Value')
            set(hspectrum,'Value',0);
            set(hcpower,'Value',0);
            set(hPlotFeat,'Value',0);
            plotmode='featim';
        end
        if get(hPlotFeat,'Value')
            if isempty (currentcolors)
                currentcolors=[ 0.75 0 0.75;  0 0.5 0 ; 0 0 1 ; 1 0 1; 1 0 0];
            end
            plotmode='featplot';
            set(hspectrum,'Value',0);
            set(hcpower,'Value',0);
            set(hImfeat,'Value',0);
        end
        switch plotmode
            case 'spectrumplot'
                [s,f,t]=spectrogram(data,rate*2,rate,4096,rate);
                imagesc(t,f,abs(s).^0.2)
                set(gca,'YDir','normal','yLim',[0 45])
                xlabel ('Time [Sec]','color','white');
                ylabel ('Freq [Hz]','color','white');
                set (gca,'XColor', 'white','YColor', 'white');
                %                 colorbar('location','WestOutside')
            case 'featplot'

                x=[[0.001  :  l-0.001] [1-0.001  :  l-0.001] ];
                x=sort(x);
                A=allfeat(:,time_s+1:time_s+l);
                y=reshape([ A ; A], [5 l*2]);
                set(gca, 'ColorOrder', currentcolors, 'NextPlot', 'replacechildren');
                plot(x,y);
                axis tight
                ylabel ('Features','color','white','FontWeight','normal');
                set (gca,'XColor', 'white','YColor', 'white','ylim',[ -1 1],'XTick',[]);
                leg=legend('Energy','Std','Length','Low \beta power','Low \gamma power');
                %                 %                 leg=legend('Feature 1','Feature 2','Feature 3','Feature 4','Feature 5');
                set(leg, 'orientation','horizontal','location','north', 'Box', 'off');
                %                 set(gca, 'ColorOrder', currentcolors, 'NextPlot', 'replacechildren');
                %                   set(gca,'ButtonDownFcn',{@selectfeatures_Callback});
            case 'featim'
                imagesc(-1*allfeat(:,time_s+1:time_s+l));
                set(gca,'yTickLabel',{'Energy' ,'STD', 'Length' ,'RP 12-20', 'RP 20-40'},'YColor', 'white');
                set (gcf,'Colormap', mycmap);
                ylabel ('Features','color','white','FontWeight','normal');
                set(gca,  'YColor', 'white','XColor', 'white' );
            case 'fftplot'
                [pxxch1, fvch1] = pwelch( data,hamming(rate*10), rate*10*0.5, 2048, rate);
                pxxch1=pxxch1/sum(pxxch1);
                p_data = bar (fvch1,pxxch1);
                xlabel ('Frequency [Hz]','color','white');
                ylabel ('Power [mV]','color','white');
                ylim ([-0.005 0.05]);

                set (gca,'XColor', 'black','YColor', 'white','Xlim', [0 45]);
            case 'reset'

                cla reset
                set (haF,'XColor',  'white');
        end
    end


    function AutoSelectNormalizationQuietCheckbox_Callback(source,eventdata)
        automaticquiet= get(hautoselectnormalizationquiet_checkbox,'value');
    end



    function deletepointsbutton_Callback(source,eventdata)

        bata=get(htable,'Data');
        if ~sum(cell2mat(bata(:,4)))
            msgbox('Select the row to be deleted');
            return
        else
            bata(cell2mat(bata(:,4)),:)=[];
            set(htable,'Data',bata);
        end
    end


    function selectpointsbutton_Callback (source,eventdata)
        global rate firstpoint

        if isempty(time_points{point_type})
            firstpoint=true;
            rowindex=1;
        else
            [rowindex,~]=size(time_points{point_type});

            if isnan(time_points{point_type}(rowindex,2))
                firstpoint=false;

            else

                firstpoint=true;
            end
        end

        graphpoints=ginput(1);
        graphpoints=round(graphpoints*100)/100 %Rounding to 2 decimal places. This is necessary because times with more than 3 decimal places are not properly converted into file coordinates in goto and DataFromTimePoints. I could round to 3, but two is easy to work with.


        if isempty(rate)
            rate=1000;
        end

        if (gca ~= ha)
            %if you did not click within the signal graph
            msgbox('hey click inside the lines biatch.')
        else
            %if you clicked in the signal graph
            time_s = str2num(get(hsecond,'string'))
            t = (time_s + graphpoints(1:end,1)/rate) %convert x coordinates clicked to times selected

            if firstpoint
                t = [t nan];
                time_points{point_type} = [time_points{point_type};t] ;

                if isempty(time_points{point_type+2})
                    time_points{point_type+2}={true};
                else
                    time_points{point_type+2} = [time_points{point_type+2};true] ; %use seizure/quiet in training = true
                end

                if point_type==2
                    if isempty(time_points{5})
                        time_points{5}={true};
                    else
                        time_points{5} = [time_points{5};true] ; %use seizure/quiet in training = true
                    end
                end
                tt=t(1);

            else

                if automaticquiet&&(point_type==2)

                    time_points{point_type}(rowindex,2) = time_points{point_type}(rowindex,1) +60;
                    time_points{point_type}(rowindex+1,1) = time_points{point_type}(rowindex,1) +60;
                    time_points{point_type}(rowindex+1,2) = t;
                    time_points{point_type+2} = [time_points{point_type+2};true] ;
                    time_points{5} = [time_points{5};false];
                else
                    time_points{point_type}(rowindex,2) = t;
                end
                tt=t;
            end
            b=get(htable,'Data');
            if ~isempty(b{1,1})
                a=cell2mat(b(:,1));

                if tt>a(end)
                    x=length(a)+1;
                else
                    x=find(tt<a,1);
                end
                b(x+1:length(a)+1,:)=b(x:end,:);
                b(x,:)={round(tt)  ' '  'Manual'   false};
                %                 set(htable,'Value',x);

            else
                b(1,:)={round(tt)  ' '  'Manual'   false};

            end
            columnformat = {'char' , 'char', {' ' 'Log' 'Seizure' 'InterIctal' 'Noise'}, 'logical'};
            columneditable =  [false false true true ];
            set(htable,'Data',b,...
                'ColumnFormat', columnformat,...
                'ColumnEditable', columneditable)

            %t=transpose(t);




            update_timepoints_table();

        end
    end


    function selectfeatures_Callback (source,eventdata)
        global  currentcolors l
        l = str2double( get (hlength,'String'));
        ColorSet = [ 0.75 0 0.75;  0 0.5 0 ; 0 0 1 ; 1 0 1; 1 0 0];
        if isempty (currentcolors)
            currentcolors=ColorSet;
        end

        if get(hPlotFeat,'Value')
            pos=(get(haF,'CurrentPoint'));
            if (pos(1,1))/l>17/60 &&  (pos(1,1))/l <21/60  &&  pos(1,2) >0.55 &&  pos(1,2) <0.8
                if currentcolors(1,:)==[1 1 1];
                    currentcolors(1,:)=ColorSet(1,:);
                else
                    currentcolors(1,:)=[1 1 1];
                end
            end
            if (pos(1,1))/l>22/60 &&  (pos(1,1))/l <25/60  &&  pos(1,2) >0.55 &&  pos(1,2) <0.8
                if currentcolors(2,:)==[1 1 1];
                    currentcolors(2,:)=ColorSet(2,:);
                else
                    currentcolors(2,:)=[1 1 1];
                end
            end
            if (pos(1,1))/l>27/60 &&  (pos(1,1))/l <30/60  &&  pos(1,2) >0.55 &&  pos(1,2) <0.8
                if currentcolors(3,:)==[1 1 1];
                    currentcolors(3,:)=ColorSet(3,:);
                else
                    currentcolors(3,:)=[1 1 1];
                end
            end
            if (pos(1,1))/l>33/60 &&  (pos(1,1))/l <38/60  &&  pos(1,2) >0.55 &&  pos(1,2) <0.8
                if currentcolors(4,:)==[1 1 1];
                    currentcolors(4,:)=ColorSet(4,:);
                else
                    currentcolors(4,:)=[1 1 1];
                end
            end
            if (pos(1,1))/l>40/60 &&  (pos(1,1))/l <45/60  &&  pos(1,2) >0.55 &&  pos(1,2) <0.8
                if currentcolors(5,:)==[1 1 1];
                    currentcolors(5,:)=ColorSet(5,:);
                else
                    currentcolors(5,:)=[1 1 1];
                end
            end
            plotfeatures_Callback
        end
    end

    function selectiontypepopup_Callback (source,evendata)
        point_type = get(hselectiontype_popup,'Value');
        if point_type==1
            set(htimepoints_table,'ColumnEditable',[true true true false])
        else
            set(htimepoints_table,'ColumnEditable',[true true true true])
        end
        update_timepoints_table();

    end

    function traintypepopup_Callback(source,eventdata)
        global parallel;
        t=get(hselecttraintype_popup,'Value');
        parallel=t-1;


    end

    function timepointstableselected_Callback(source,eventdata)
        timepoints_table_rowsselected =eventdata.Indices(:,1);
        if length(eventdata.Indices)==0
            return;
        end

        if (size(eventdata.Indices) == [1,2]) %if just one row is selected

            if eventdata.Indices(1,2) <3 %if its not a checkbox column
                bata=get(htimepoints_table,'Data');
                second=bata(eventdata.Indices(1),eventdata.Indices(2));
                second = round(second{1}*100)/100; %Round the number to two decimal places, so gotocenter doesn't go fucking insane
                set(hgoto,'String',second);
                %                 gotobutton_Callback
                gotocenter_Callback
                DrawSeizureAndQuietMarks
            end
        end
    end

    function timepointstableedit_Callback(source,eventdata)
        index=eventdata.Indices;

        if index(2)<3
            %if its not a checkbox column
            new=eventdata.NewData;
            new=round(new*100)/100; %Round to 2 decimals as explained in the select points function
            time_points{point_type}(index(1),index(2))= new;
            DrawSeizureAndQuietMarks();
        elseif index(2)==3
            %if it is the first checkbox column

            time_points{point_type+2}(index(1))= {eventdata.NewData};
        elseif index(2)==4
            %if its second check box column
            if point_type==2
                time_points{5}(index(1))= {eventdata.NewData};
            end

        end

    end

    function removerowsbutton_Callback(source,eventdata)
        time_points{point_type}(timepoints_table_rowsselected,:) =[];
        time_points{point_type+2}(timepoints_table_rowsselected,:) =[];
        if point_type==2
            time_points{5}(timepoints_table_rowsselected,:) =[];
        end
        update_timepoints_table();
    end

    function update_timepoints_table

        if point_type ==1
            newdata=[num2cell(time_points{point_type}(:,:))...
                time_points{point_type+2}(:)...
                num2cell(logical(zeros(length(time_points{point_type+2}),1))) ];
        else
            newdata=[num2cell(time_points{point_type}(:,:))...
                time_points{point_type+2}(:)...
                time_points{5}(:) ];
        end


        set(htimepoints_table,'Selected','off');
        set(htimepoints_table,'Data',newdata);

        DrawSeizureAndQuietMarks();
    end

    function wdata=CalculateTrainFeatures(sigdata)
        global rate threshold numberfeatures
        if isempty(rate)
            rate=1000;
        end

        if isempty(threshold)
            threshold =1.2;

            % msgbox('Threshold was set by default to 1.2mV','Threshold settings');
        end

        if isempty(numberfeatures)
            numberfeatures =1;
        end

        if isempty(sigdata)
            wdata={};
            return
        end


        LP=[];
        switch rate
            case 200
                a=load('HP_fs200_fc2_order200.mat');
                HP=a.HP_fs200_fc2_order200;
            case 500
                a=load('HP_fs500_fc2_order400.mat');
                HP=a.HP_fs500_fc2_order400;
            case 1000
                a=load('LP_fs1000_fc250_order600.mat');
                LP=a.LP_fs1000_fc250_order600;
                a=load('HP_fs500_fc2_order400.mat');
                HP=a.HP_fs500_fc2_order400;
        end



        %%  Calculate features
        %data=DataFromTimePoints(time_points{point_type})
        wdata={};

        if numberfeatures==1% 5  features
            for n = 1:length(sigdata)
                wdata =[wdata  winny5_(sigdata{n},rate,threshold,HP,LP)];

            end;




        else% 22  features
            for n = 1:length(data)
                wdata =[wdata  winny22(sigdata{n},rate,threshold,HP,LP)];

            end;


        end;
    end

    function [signal_data]=DataFromTimePoints(points)
        global rate dirct
        if (not(isempty(points)))
            %points is at n by 2 matrix of time points.
            if isempty(rate)
                rate = 1000;
            end

            readpoints = []; %read points is like points, but in terms of file ids and not time
            readpoints(:,1) =   points(:,1) * 4 * rate;
            readpoints(:,2) = points(:,2)*4*rate;

            file_name = dirct;
            %         file_name = get(hraw,'String');
            fidf = fopen (file_name,'r+');


            [rows,~] = size(readpoints);
            signal_data = cell(1,rows);

            for n=1:rows

                fseek(fidf, readpoints(n,1),-1);
                signal_data{n}= fread(fidf, abs(readpoints(n,2)-readpoints(n,1))/4,'float32');

            end
        else
            signal_data=[];

        end

    end

    function animal_struct=PrepareAnimalStructure()
        global rate threshold

        SeizureData = DataFromTimePoints(time_points{1});
        QuietData = DataFromTimePoints(time_points{2});

        animal_struct = struct('FileName',get(hraw,'string'),...
            'Rate',rate,...
            'Threshold',threshold,...
            'SeizureTimePoints',time_points{1},...
            'QuietTimePoints',time_points{2},...
            'SeizureData',{SeizureData},...
            'QuietData',{QuietData},...
            'SeizureFeatures',{CalculateTrainFeatures(SeizureData)},...
            'QuietFeatures',{CalculateTrainFeatures(QuietData)},...
            'UseSeizure',time_points(3),...
            'UseQuiet',time_points(4),...
            'NormalizeToQuiet',time_points(5));



    end

    function AddToTrainingFolderButton_Callback(source,eventdata)
        [LoadedTrainingFile,LoadedTrainingDir]=uiputfile( '*.mat','Save New Training File');
        animal = PrepareAnimalStructure();
        save(strcat(LoadedTrainingDir,LoadedTrainingFile),'animal');

    end

    function SaveAnimalButton_Callback(source,eventdata)
        animal = PrepareAnimalStructure();
        if strcmp(CurrentTrainingAnimalName,'New Animal')|| isempty(CurrentTrainingAnimalName)
            NewAnimalFileName = strcat(inputdlg('Name Animal:','Name Animal',1) ,'.mat');
            save(char(strcat(TrainingFolder,NewAnimalFileName)),'animal');
            CurrentTrainingAnimal=NewAnimalFileName;
        else
            save(char(strcat(TrainingFolder,CurrentTrainingAnimalName)),'animal');
        end
        msgbox([ CurrentTrainingAnimalName ' was saved in : ' TrainingFolder],'You did it!!!', 'help')
        UpdateAnimalsTable();

    end

    function LoadTrainingFolderButton_Callback(source,eventdata)
        [LoadedTrainingFile,LoadedTrainingDir] = uigetfile2('','Select A Training Folder to Load');

        UpdateSelectAnimalList();
    end

    function UpdateSelectAnimalList()
        d = dir([LoadedTrainingDir '*.mat']);
        names=['New Animal' {d.name}];
        set(hselectanimal_popup,'Value',1);
        set(hselectanimal_popup,'String',names);
    end

    function UpdateAnimalsTable()
        d = dir([TrainingFolder '*.mat']);
        TrainingAnimalNames=vertcat('New Animal',{d.name}');

        UseAnimalinTraining=num2cell(logical(vertcat(0, ones(length(TrainingAnimalNames)-1,1))));


        set(hselectanimal_table,'data',[TrainingAnimalNames UseAnimalinTraining]);
    end

    function EditAnimalTable_Callback(source,eventdata)
        n = eventdata.Indices;
        n=n(1,1);

        UseAnimalinTraining{n}=eventdata.NewData;
    end

    function SelectAnimalTable_Callback(source,eventdata)


        n = eventdata.Indices;
        if isempty  (n)
            n=ones(1,2);
        end

        %             n=get(hanimaltable) end
        if n(1,2)==1
            n=n(1,1);

            FileToLoadName= TrainingAnimalNames(n);
            %   if isempty(CurrentTrainingAnimalName)end

            if strcmp(CurrentTrainingAnimalName, FileToLoadName)
                %             msgbox('This Animal is already loaded');
                return %exit function early
            else

                choice = questdlg('Make sure to save current animal before loading new one.', ...
                    'Have you Saved?', ...
                    'Continue','Cancel','Cancel');

                switch choice
                    case 'Continue'
                        %continue as normal
                    case 'Cancel'
                        return %exit function early
                end

                if strcmp(FileToLoadName,'New Animal')
                    %time_points = {[],[],[],[],[]};

                else


                    current_animal = load(char(strcat(TrainingFolder,FileToLoadName)));
                    current_animal=current_animal.animal;

                    time_points(1) = {current_animal.SeizureTimePoints};
                    time_points(2) = {current_animal.QuietTimePoints};
                    time_points(3) = {current_animal.UseSeizure};
                    time_points(4) = {current_animal.UseQuiet};
                    time_points(5)= {current_animal.NormalizeToQuiet};
                    [FilePath,FileName,FileExt] = fileparts(current_animal.FileName);


                    loadraw([FileName FileExt],FilePath); %Load associated raw signal file
                end
            end
            CurrentTrainingAnimalName=FileToLoadName;
            update_timepoints_table();
        end

    end

    function NumberOfSegmentsEdit_Callback(source,eventdata)
        global TotalSegments
        new_num=str2num(get(hnumberofsegments_edit,'String'))

        if isempty(new_num)
            msgbox('Please enter a numeric value','Numeric Value Required');
            set(hnumberofsegments_edit,'String',num2str(TotalSegments));
            return
        end

        if new_num>25
            choice = questdlg('Segment number is large, continue anyway?', ...
                'Warning: Segment Number Large', ...
                'Continue','Cancel','Cancel');

            switch choice
                case 'Continue'
                    %continue as normal
                case 'Cancel'
                    set(hnumberofsegments_edit,'String',num2str(TotalSegments));
                    return
            end
        end


        TotalSegments=new_num; %if no errors, update total segments

    end

    function LengthOfSegmentsEdit_Callback(source,eventdata)
        global SegmentInterval
        new_num=str2num(get(hnumberofsegments_edit,'String'))

        if isempty(new_num)
            msgbox('Please enter a numeric value','Numeric Value Required');
            set(hlengthofsegments_edit,'String',num2str(SegmentInterval));
            return
        end

        if new_num>25
            choice = questdlg('Segment duration is large, continue anyway?', ...
                'Warning: Segment Duration Large', ...
                'Continue','Cancel','Cancel');

            switch choice
                case 'Continue'
                    %continue as normal
                case 'Cancel'
                    set(hnumberofsegments_edit,'String',num2str(TotalSegments));
                    return
            end
        end


        SegmentInterval=new_num; %if no errors, update total segments

    end

    function TrainButton_Callback(source,eventdata)
        global SegmentInterval TotalSegments parallel
        if isempty(SegmentInterval)
            SegmentInterval=5;
        end
        if isempty(TotalSegments)
            TotalSegments=5;
        end
        if isempty(parallel)
            parallel=0;
        end


        if parallel >0
            T=TotalSegments;
        elseif parallel==0
            T=1;
        end

        nets=cell(1,T);
        netnames=cell(1,T);
        netrecords=cell(1,T);
        Secondmapsettings=cell(1,T);


        NetFileName = strcat(inputdlg('Name Network:','Name Network',1) ,'.mat');
        NetFileName=cell2mat(NetFileName);
        NetworkDescription = inputdlg('Describe Network:','Describe Network',3);
        TrainingDataSets={};
        TrainingKeySets={};
        AllRawDataSets={};
        for n=1:T


            [TrainingData,TrainingKey,Secondmapsetting,AllRawData,AnimalsUsedForTraining,SeizureTimePointsUsedForTraining,QuietTimePointsUsedForTraining,NormalizationQuietTimePointsUsedForTraining]=PrepareParallelTrainingData(n);


            %train Networks:


            net = newff(TrainingData,TrainingKey,50,{},'traincgb');%creates the network
            net.trainParam.epochs=500;%max No of itteartions
            net.inputs{1,1}.processFcns={};
            [net,tr,Y,E,Pf,Af]   = train(net,TrainingData,TrainingKey);%train the network
            netname=strcat(NetFileName,'_',num2str(n));

            netnames{n}=netname;
            nets{n}=net;
            netrecords{n}=tr;
            Secondmapsettings{n}=Secondmapsetting;
            TrainingDataSets=[TrainingDataSets {TrainingData}];
            TrainingKeySets=[TrainingKeySets {TrainingKey}];
            AllRawDataSets=[AllRawDataSets {AllRawData}];
        end

        %NetworkName = inputdlg('Name Network:','Name Network',1);
        %NetFilePath = [pwd '\Networks\'];)

        %[NetFileName,NetFilePath] = uiputfile('*.mat','Save Network File');

        if parallel==0
            TrainingMethod='Regular';

        elseif parallel==1
            TrainingMethod='Subdivide';
        elseif parallel==2
            TrainingMethod='Subdivide Incrementally';
        end

        save(strcat(NetFolder,NetFileName),'nets','netnames','Secondmapsettings','NetworkDescription','netrecords','TrainingDataSets','TrainingKeySets','AllRawDataSets','TotalSegments','SegmentInterval','TrainingMethod','AnimalsUsedForTraining','SeizureTimePointsUsedForTraining','QuietTimePointsUsedForTraining','NormalizationQuietTimePointsUsedForTraining');
        PrepareNetMenu()
    end

    function [TrainingData,TrainingKey,Secondmapsettings,RawData,AnimalsUsedForNetwork,SeizureTimePointsUsedForNetwork,QuietTimePointsUsedForNetwork,NormalizationQuietTimePointsUsedForNetwork]=PrepareParallelTrainingData(numbersegment)
        global SegmentInterval parallel;

        if isempty(SegmentInterval)
            SegmentInterval=5;
        end

        if isempty(parallel)
            parallel=0;
        end

        if parallel==1
            train_index =((numbersegment-1)*SegmentInterval) +1; %in this case you start reading at train_index till train_index+segmentinterval
        elseif parallel==2
            train_index= numbersegment*SegmentInterval; %in this case you start reading at 0 till train_index
        end


        %      d = dir([LoadedTrainingDir '*.mat']);
        %         names={d.name};

        TrainingData=[];
        TrainingKey=[];
        AnimalsUsedForNetwork={};
        SeizureTimePointsUsedForNetwork={};
        QuietTimePointsUsedForNetwork={};
        NormalizationQuietTimePointsUsedForNetwork={};

        RawData=[];

        for n =1:length(TrainingAnimalNames)

            if UseAnimalinTraining{n}

                animal = load(char(strcat(TrainingFolder,TrainingAnimalNames{n})));
                animal= animal.animal;
                AnimalsUsedForNetwork=[AnimalsUsedForNetwork TrainingAnimalNames{n}];

                if parallel>0
                    [s,s_tp]=PasteParallelFeaturesorData(animal.SeizureTimePoints,animal.SeizureFeatures,animal.UseSeizure,train_index);
                    [NewRawData,~]=PasteParallelFeaturesorData(animal.SeizureTimePoints,animal.SeizureData,animal.UseSeizure,train_index);
                    RawData=vertcat(RawData,NewRawData);


                elseif parallel==0
                    [s,s_tp]=PasteParallelFeaturesorData(animal.SeizureTimePoints,animal.SeizureFeatures,animal.UseSeizure,-1);
                    [NewRawData,~] =PasteParallelFeaturesorData(animal.SeizureTimePoints,animal.SeizureData,animal.UseSeizure,-1);
                    RawData=vertcat(RawData,NewRawData);


                end

                if length(s)>0

                    [q,q_tp]=PasteParallelFeaturesorData(animal.QuietTimePoints,animal.QuietFeatures,animal.UseQuiet,-1);
                    [nq,nq_tp]=PasteParallelFeaturesorData(animal.QuietTimePoints,animal.QuietFeatures,animal.NormalizeToQuiet,-1);
                    [NewRawData,~]=PasteParallelFeaturesorData(animal.QuietTimePoints,animal.QuietData,animal.UseQuiet,-1);
                    RawData=vertcat(RawData,NewRawData );

                    SeizureTimePointsUsedForNetwork=[SeizureTimePointsUsedForNetwork s_tp];
                    QuietTimePointsUsedForNetwork = [QuietTimePointsUsedForNetwork q_tp];
                    NormalizationQuietTimePointsUsedForNetwork = [NormalizationQuietTimePointsUsedForNetwork nq_tp];


                    [~,firstmap,~,s,q]=NormalizeFeatures(s,q,nq);
                    if ~(length(firstmap)==1)
                        TrainingData=[TrainingData firstmap];

                        [length_s,~]=size(s);
                        [length_q,~]=size(q);
                        TrainingKey = [TrainingKey ones(1,length_s) -1*ones(1,length_q)];
                        %Seizure= [Seizure' PasteFeatures(animal.SeizureFeatures,animal.UseSeizure)']';
                        %Quiet= [Quiet' PasteFeatures(animal.QuietFeatures,animal.UseQuiet)']';
                    end


                end
            end
        end

        [TrainingData,Secondmapsettings]=mapminmax(TrainingData);

    end

    function [final_features,timepointsused]=PasteParallelFeaturesorData(timepoints,features,use_features,train_index)
        %n is from the calling function createkey.
        %features is  a cell array of the features to be pasted together.
        %use_features is a cell array of equal length to features, telling
        %whether or not the features with matching index in features should be
        %used while pasting.
        global SegmentInterval parallel


        final_features=[];
        timepointsused=[];
        if isempty(use_features)
            return;
        end
        for n=1:length(features)



            if (use_features{n})



                timepointsused=vertcat(timepointsused,timepoints(n,:));
                if train_index>0
                    if parallel==1
                        if ~(train_index>=length(features{n}))

                            if train_index+SegmentInterval>length(features{n})
                                final_features=vertcat(final_features, features{n}(train_index:length(features{n}),:)) ;

                            else
                                final_features=vertcat(final_features, features{n}(train_index:train_index+SegmentInterval,:)) ;
                            end


                        end


                    elseif parallel==2
                        if train_index<=length(features{n})
                            final_features=vertcat(final_features, features{n}(1:train_index,:)) ;
                        else
                            final_features=vertcat(final_features, features{n}(1:length(features{n}),:)) ;
                        end






                    end

                else
                    %if you're not segmenting the features
                    final_features=vertcat(final_features, features{n}) ;
                end

            end


        end
    end

    function [mapped,firstmap,Qmapsettings,Seizure,Quiet]=NormalizeFeatures(Seizure,Quiet,NormalizationQuiet)
        global rate sensitivity threshold netrout animal

        if isempty(rate)
            rate=1000;end

        if isempty(sensitivity)
            sensitivity=0.15;end

        %         annhold = str2double(get(hdetect,'String'));;
        if isempty (threshold)
            threshold=1.2;
        end

        %Remove noise:

        %i)Normalize Quiet between -1&1:

        [mapped Qmapsettings]=mapminmax(NormalizationQuiet');


        wdata=nan(size(Seizure));



        all=[];
        %ii)Normalize Training Data to Quiet:
        clear('firstmap','secmap','yy');
        ind=find(isnan(Seizure(1,:)) );% remove nans
        restind=setdiff(1:length(wdata),ind);
        Seizure(:,ind)=[];

        wdata=nan(size(Quiet));
        ind=find(isnan(Quiet(1,:)) );% remove nans
        restind=setdiff(1:length(wdata),ind);
        Quiet(:,ind)=[];

        if ~(length(Seizure)==0 || length(Quiet)==0)
            newW = [Seizure' Quiet'];

            [firstmap]= mapminmax('apply' ,newW, Qmapsettings); %ADJUST MAPPING STRUCTURE
        else
            firstmap=-1;
        end



        %iii)Normalize ii) between -1&1:

        %[secmap Secondmapsettings]= mapminmax(firstmap);


    end

    function loadnetworkandanalyzebutton_Callback(source,eventdata)


        global all allfeat allindex rate Qdata threshold;


        if isempty(rate)
            rate=1000;
        end

        if isempty(threshold)
            threshold=1.2;
        end

        PathName = (get(hdir,'String'));;
        LP=[];


        switch rate
            case 200
                a=load('HP_fs200_fc2_order200.mat');
                HP=a.HP_fs200_fc2_order200;
            case 500
                a=load('HP_fs500_fc2_order400.mat');
                HP=a.HP_fs500_fc2_order400;
            case 1000
                a=load('LP_fs1000_fc250_order600.mat');
                LP=a.LP_fs1000_fc250_order600;
                a=load('HP_fs500_fc2_order400.mat');
                HP=a.HP_fs500_fc2_order400;
        end

        %         agg=get(haggregate,'value');
        allfeat=[];
        allfeat_firstmap=[];



        if isempty(all)
            all={};
        end

        PathName = (get(hdir,'String'));;
        allfeat=[];
        allfeat_firstmap=[];

        [LoadedNetFile,LoadedNetDir] = uigetfile2('*.mat','Load Network....');
        LoadedNet= load([LoadedNetDir LoadedNetFile],'net');
        LoadedNet = LoadedNet.net;

        secondmapsettings = load([LoadedNetDir LoadedNetFile],'Secondmapsettings');
        secondmapsettings = secondmapsettings.Secondmapsettings;

        % Q=load([LoadedNetDir LoadedNetFile],'Qmapsettings');
        % Q=Q.Qmapsettings;

        %For 5 Features, Seizure:
        [wdata]  =  winny5_ (Qdata,rate,threshold,HP,LP);
        [mapped Q]=mapminmax(wdata');


        wdataFOLDER=[PathName '\'];
        L=length(dir(wdataFOLDER))-2;
        % all=[];
        allthisnet=[]; %all, but only for the network being currently loaded


        for i=1:L
            %Loading and Normalizing signal features:
            clear('firstmap','secmap','yy');
            newW= load(  [wdataFOLDER num2str(i)  'wdata.csv'])';%load w data
            wdata=nan(size(newW));
            ind=find(isnan(newW(1,:)) );% remove nans
            restind=setdiff(1:length(wdata),ind);
            newW(:,ind)=[];
            [firstmap]= mapminmax('apply' ,newW, Q);  %ADJUST MAPPING STRUCTURE

            secmap= mapminmax('apply' ,firstmap,secondmapsettings);

            %Running through networks:

            % s = con2seq(S);
            yy= sim(LoadedNet,secmap);

            % output=cell2mat(yy);
            OUTPUT=nan(1,length(wdata));
            OUTPUT(restind)=yy; %preserving time correlation


            allthisnet=[allthisnet OUTPUT];

            %                 if agg;

            wdata(:,restind)=secmap;
            allfeat=[allfeat wdata];




        end

        all = [all allthisnet];


    end

    function prepareall(allthisnet)

    end

    function keypress_Callback(source,eventdata)
        %handle keyboard input to main form
        if strcmp(char(get(htrainpanel,'Visible')),char('on'))

            if eventdata.Key == 'u'
                set(hselectiontype_popup,'Value',1)
                selectiontypepopup_Callback();
            end

            if eventdata.Key == 'q'
                set(hselectiontype_popup,'Value',2)
                selectiontypepopup_Callback();
            end


            if eventdata.Key == 's'
                selectpointsbutton_Callback();
            end

        end
        %                                if ~strcmp(get( hQuiet,'String'),'File Name');

        if strcmp(eventdata.Key , 'rightarrow')
            nextbutton_Callback
        end
        if strcmp(eventdata.Key, 'leftarrow')
            Previousbutton_Callback
        end
        %                                end
    end

%% FREQUENCY
    function f1000 (source,eventdata,handle)
        global rate data_samp
        rate=1000;
        set(gcbo, 'Checked', 'on');
        set(F2, 'Checked', 'off');
        set(F3, 'Checked', 'off');
        l = str2double( get (hlength,'String'));
        data_samp = rate*l;
        tostartbutton_Callback;
    end
    function f500 (source,eventdata,handle)
        global rate data_samp
        rate=500;
        set(gcbo, 'Checked', 'on');
        set(F1, 'Checked', 'off');
        set(F3, 'Checked', 'off');
        l = str2double( get (hlength,'String'));
        data_samp = rate*l;
        tostartbutton_Callback;
    end
    function f200 (source,eventdata,handle)
        global rate data_samp
        rate=200;
        set(gcbo, 'Checked', 'on');
        set(F1, 'Checked', 'off');
        set(F2, 'Checked', 'off');
        l = str2double( get (hlength,'String'));
        data_samp = rate*l;
        tostartbutton_Callback
    end
%% NUMBER OF FEATURES
    function f5 (source,eventdata,handle)
        global numberfeatures
        numberfeatures=1;
        set(gcbo, 'Checked', 'on');
        set(F22, 'Checked', 'off');
        FeatMenu



    end
    function f22 (source,eventdata,handle)
        global numberfeatures
        numberfeatures=2;
        set(gcbo, 'Checked', 'on');
        set(F5, 'Checked', 'off');
        FeatMenu

    end
%% Net Menu
    function NetMenu (source,eventdata,handle)
        global  netrout UseNets NetGroupNames
        if strcmp(get(gcbo,'Checked'),'on')
            set(gcbo, 'Checked', 'off');

            hparent=get(gcbo,'Parent');
            if ~(hparent==hnet)
                UseNets{get(hparent,'Position')}(get(gcbo,'Position'),1)=0;
            else
                if length(UseNets{get(gcbo,'Position')})==1
                    UseNets{get(gcbo,'Position')}(1,1)=0;
                end
            end
        else
            set(gcbo, 'Checked', 'on');

            hparent=get(gcbo,'Parent');
            if ~(hparent==hnet)
                UseNets{get(hparent,'Position')}(get(gcbo,'Position'),1)=1;
            else
                if length(UseNets{get(gcbo,'Position')})==1
                    UseNets{get(gcbo,'Position')}(1,1)=1;
                end
            end
        end


    end

    function PrepareNetMenu()
        global NetGroupNames UseNets AllNetNames
        %         if ~isempty(NetGroupNames)% adding one net
        %             newNetGroupNames=dir([NetFolder '*.mat']);
        %             S = [newNetGroupNames(:).datenum].'; % you may want to eliminate . and .. first.
        %             [S,S] = sort(S);
        %             Snames = {newNetGroupNames(flipud(S)).name}'; % Cell array of names in order by datenum.
        %
        %             NetGroupNames=Snames(1);
        %             netnames=load([NetFolder '\' NetGroupNames{1}],'netnames');
        %             netnames=netnames.netnames;
        %             UseNets{end+1}=zeros(length(netnames),1);
        %             hands={};
        %             for idx = 1:length(NetGroupNames)
        %                 hands{idx}= uimenu('Parent',hnet,...
        %                     'Label',NetGroupNames{idx},...
        %                     'Callback',@NetMenu,...
        %                     'Tag',strcat('N',idx));
        %
        %                 if length(AllNetNames{idx})>1
        %                     for i=1:length(AllNetNames{idx})
        %                         uimenu('Parent',hands{idx},...
        %                             'Label',AllNetNames{idx}{i},...
        %                             'Callback',@NetMenu,...
        %                             'Tag',strcat('N',idx));
        %                     end
        %                 end
        %
        %             end
        %
        %         else % new list
        NetGroupNames=dir([NetFolder '*.mat']);
        NetGroupNames={NetGroupNames(:).name};
        hands={};
        AllNetNames={};
        %             delete(hands{:});

        UseNets=cell(1,length(NetGroupNames));

        for b= 1:length(NetGroupNames)
            if strcmp(NetGroupNames{b},'net_219.mat');
                ind219=b;
            end
        end
        UseNets{ind219}=1;

        for n=1:length(NetGroupNames)
            netnames=load([NetFolder '\' NetGroupNames{n}],'netnames');
            netnames=netnames.netnames;
            AllNetNames=[AllNetNames {netnames}];
            UseNets{n}=zeros(length(netnames),1);
        end

        hands={};
        for idx = 1:length(NetGroupNames)
            hands{idx}= uimenu('Parent',hnet,...
                'Label',NetGroupNames{idx},...
                'Callback',@NetMenu,...
                'Tag',strcat('N',idx));

            if length(AllNetNames{idx})>1
                for i=1:length(AllNetNames{idx})
                    uimenu('Parent',hands{idx},...
                        'Label',AllNetNames{idx}{i},...
                        'Callback',@NetMenu,...
                        'Tag',strcat('N',idx));
                end
            end
        end
        set(hands{ind219},'Checked','on');
        %         end
    end

    function Netother (source,eventdata,handle)
        global netrout
        set(gcbo, 'Checked', 'on');
        set(N1, 'Checked', 'off');
        set(N2, 'Checked', 'off');
        set(N3, 'Checked', 'off');
        netrout=uigetfile2('*.mat');
        set(gcbo,'Label',netrout(1:end-4));
    end

%%  SENSETIVITY CALLBACKS
    function class_method (source,eventdata,handle)
        if strcmp(get(gcbo, 'Checked'), 'on');
            set(gcbo, 'Checked', 'off'); else
            set(gcbo, 'Checked', 'on');end
    end

    function TH1 (source,eventdata,handle)
        global  sensitivity
        set(ann, 'Checked', 'on');
        set(gcbo, 'Checked', 'on');
        set(T2, 'Checked', 'off');
        set(T3, 'Checked', 'off');
        set(Tother, 'Checked', 'off');
        set(slope, 'Checked', 'off');
        set(Sl1, 'Checked', 'off');
        set(Sl2, 'Checked', 'off');
        set(Sl3, 'Checked', 'off');
        set(Slother, 'Checked', 'off');
        sensitivity=1;
    end
    function TH2 (source,eventdata,handle)
        global sensitivity
        set(ann, 'Checked', 'on');
        set(gcbo, 'Checked', 'on');
        set(T1, 'Checked', 'off');
        set(T3, 'Checked', 'off');
        set(Tother, 'Checked', 'off');
        set(slope, 'Checked', 'off');
        set(Sl1, 'Checked', 'off');
        set(Sl2, 'Checked', 'off');
        set(Sl3, 'Checked', 'off');
        set(Slother, 'Checked', 'off');
        sensitivity=0.9;
    end
    function TH3 (source,eventdata,handle)
        global sensitivity
        set(ann, 'Checked', 'on');
        set(gcbo, 'Checked', 'on');
        set(T1, 'Checked', 'off');
        set(T2, 'Checked', 'off');
        set(Tother, 'Checked', 'off');
        set(slope, 'Checked', 'off');
        set(Sl1, 'Checked', 'off');
        set(Sl2, 'Checked', 'off');
        set(Sl3, 'Checked', 'off');
        set(Slother, 'Checked', 'off');
        sensitivity=0.8;
    end
    function THother (source,eventdata,handle)
        global sensitivity
        set(ann, 'Checked', 'on');
        ff = figure('Visible','on','Position',[500,400,100,50],'Name','Sensitivity','NumberTitle','off',...
            'MenuBar','none',...
            'IntegerHandle','off',...
            'Units','normalized');
        currentCustomSensitivity=0;
        hdetect = uicontrol('Parent',ff,'Style','edit','String',num2str(sensitivity),'position',[15,10,80,15],'BackgroundColor','white','FontSize',10,'Callback',{@sensitivityx});
        function sensitivityx(source,eventdata,handle)
            sensitivity=get(hdetect,'String');
            set(Tother,'Label',sensitivity);
            sensitivity=str2num(sensitivity);
        end
        set(gcbo, 'Checked', 'on');
        set(T1, 'Checked', 'off');
        set(T2, 'Checked', 'off');
        set(T3, 'Checked', 'off');
        set(slope, 'Checked', 'off');
        set(Sl1, 'Checked', 'off');
        set(Sl2, 'Checked', 'off');
        set(Sl3, 'Checked', 'off');
        set(Slother, 'Checked', 'off');
    end

    function SlH1 (source,eventdata,handle)
        global  slopetivity
        set(get(gcbo,'Parent'), 'Checked', 'on');
        set(gcbo, 'Checked', 'on');
        set(Sl2, 'Checked', 'off');
        set(Sl3, 'Checked', 'off');
        set(Slother, 'Checked', 'off');
        set(T1, 'Checked', 'off');
        set(T2, 'Checked', 'off');
        set(T3, 'Checked', 'off');
        set(Tother, 'Checked', 'off');
        slopetivity=1;
    end
    function SlH2 (source,eventdata,handle)
        global slopetivity
        set(slope, 'Checked', 'on');
        set(gcbo, 'Checked', 'on');
        set(Sl1, 'Checked', 'off');
        set(Sl3, 'Checked', 'off');
        set(Slother, 'Checked', 'off');
        set(T1, 'Checked', 'off');
        set(T2, 'Checked', 'off');
        set(T3, 'Checked', 'off');
        set(Tother, 'Checked', 'off');
        slopetivity=0.9;
    end
    function SlH3 (source,eventdata,handle)
        global slopetivity
        set(slope, 'Checked', 'on');
        set(gcbo, 'Checked', 'on');
        set(Sl1, 'Checked', 'off');
        set(Sl2, 'Checked', 'off');
        set(Slother, 'Checked', 'off');
        set(T1, 'Checked', 'off');
        set(T2, 'Checked', 'off');
        set(T3, 'Checked', 'off');
        set(Tother, 'Checked', 'off');
        slopetivity=0.8;
    end
    function SlHother (source,eventdata,handle)
        global slopetivity
        set(slope, 'Checked', 'on');
        ff = figure('Visible','on','Position',[500,400,100,50],'Name','Sensitivity','NumberTitle','off',...
            'MenuBar','none',...
            'IntegerHandle','off',...
            'Units','normalized');
        hdetect = uicontrol('Parent',ff,'Style','edit','String',num2str(slopetivity),'position',[15,10,80,15],'BackgroundColor','white','FontSize',10,'Callback',{@slopetivityx});
        function slopetivityx(source,eventdata,handle)
            slopetivity=get(hdetect,'String');
            set(Slother,'Label',slopetivity);
            slopetivity=str2num(slopetivity);
        end
        set(gcbo, 'Checked', 'on');
        set(Sl1, 'Checked', 'off');
        set(Sl2, 'Checked', 'off');
        set(Sl3, 'Checked', 'off');
        set(T1, 'Checked', 'off');
        set(T2, 'Checked', 'off');
        set(T3, 'Checked', 'off');
        set(Tother, 'Checked', 'off');

    end
%%  NOISE TH CALLBACKS
    function NTH1 (source,eventdata,handle)
        global  threshold
        set(gcbo, 'Checked', 'on');
        set(NT2, 'Checked', 'off');
        set(NT3, 'Checked', 'off');
        set(NT4, 'Checked', 'off');
        set(NT5, 'Checked', 'off');
        set(NT6, 'Checked', 'off');
        set(NTother, 'Checked', 'off');
        threshold=0.6;
    end
    function NTH2(source,eventdata,handle)
        global  threshold
        set(gcbo, 'Checked', 'on');
        set(NT1, 'Checked', 'off');
        set(NT3, 'Checked', 'off');
        set(NT4, 'Checked', 'off');
        set(NT5, 'Checked', 'off');
        set(NT6, 'Checked', 'off');
        set(NTother, 'Checked', 'off');
        threshold=0.8;
    end
    function NTH3(source,eventdata,handle)
        global  threshold
        set(gcbo, 'Checked', 'on');
        set(NT1, 'Checked', 'off');
        set(NT2, 'Checked', 'off');
        set(NT4, 'Checked', 'off');
        set(NT5, 'Checked', 'off');
        set(NT6, 'Checked', 'off');
        set(NTother, 'Checked', 'off');
        threshold=1;
    end
    function NTH4(source,eventdata,handle)
        global  threshold
        set(gcbo, 'Checked', 'on');
        set(NT1, 'Checked', 'off');
        set(NT2, 'Checked', 'off');
        set(NT3, 'Checked', 'off');
        set(NT5, 'Checked', 'off');
        set(NT6, 'Checked', 'off');
        set(NTother, 'Checked', 'off');
        threshold=1.2;
    end
    function NTH5(source,eventdata,handle)
        global  threshold
        set(gcbo, 'Checked', 'on');
        set(NT1, 'Checked', 'off');
        set(NT2, 'Checked', 'off');
        set(NT3, 'Checked', 'off');
        set(NT4, 'Checked', 'off');
        set(NT6, 'Checked', 'off');
        set(NTother, 'Checked', 'off');
        threshold=1.4;
    end
    function NTH6(source,eventdata,handle)
        global  threshold
        set(gcbo, 'Checked', 'on');
        set(NT1, 'Checked', 'off');
        set(NT2, 'Checked', 'off');
        set(NT3, 'Checked', 'off');
        set(NT4, 'Checked', 'off');
        set(NT5, 'Checked', 'off');
        set(NTother, 'Checked', 'off');
        threshold=1.6;
    end
    function NTHother (source,eventdata,handle)
        global threshold
        ff = figure('Visible','on','Position',[900,800,100,50]/2,'Name','Threshold','NumberTitle','off',...
            'MenuBar','none',...
            'IntegerHandle','off',...
            'Units','normalized');
        hnoise = uicontrol('Parent',ff,'Style','edit','String',num2str(threshold),'position',[15,10,80,15],'BackgroundColor','white','FontSize',10,'Callback',{@sensitivityx});
        function sensitivityx(source,eventdata,handle)
            threshold=get(hnoise,'String');
            set(NTother,'Label',threshold);
            threshold=str2num(threshold);
        end
        set(gcbo, 'Checked', 'on');
        set(NT1, 'Checked', 'off');
        set(NT2, 'Checked', 'off');
        set(NT3, 'Checked', 'off');
        set(NT4, 'Checked', 'off');
        set(NT5, 'Checked', 'off');
        set(NT6, 'Checked', 'off');
    end

%%  DURATION CALLCACKS
    function SH6(source,eventdata,handle)
        global duration
        duration= 6;
        set(gcbo, 'Checked', 'on');
        set(S2, 'Checked', 'off');
        set(S4, 'Checked', 'off');
        set(S6, 'Checked', 'off');
        set(S8, 'Checked', 'off');
        set(S10, 'Checked', 'off');
        set(SO, 'Checked', 'off');
    end
    function SH8(source,eventdata,handle)
        global duration
        duration= 8;
        set(gcbo, 'Checked', 'on');
        set(S2, 'Checked', 'off');
        set(S4, 'Checked', 'off');
        set(S6, 'Checked', 'off');
        set(S10, 'Checked', 'off');
        set(SO, 'Checked', 'off');
    end
    function SH10(source,eventdata,handle)
        global duration
        duration= 10;
        set(gcbo, 'Checked', 'on');
        set(S2, 'Checked', 'off');
        set(S4, 'Checked', 'off');
        set(S6, 'Checked', 'off');
        set(S8, 'Checked', 'off');
        set(SO, 'Checked', 'off');
    end
    function SH4(source,eventdata,handle)
        global duration
        duration= 4;
        set(gcbo, 'Checked', 'on');
        set(S2, 'Checked', 'off');
        set(S6, 'Checked', 'off');
        set(S8, 'Checked', 'off');
        set(S10, 'Checked', 'off');
        set(SO, 'Checked', 'off');
    end
    function SH2(source,eventdata,handle)
        global duration
        duration= 2;
        set(gcbo, 'Checked', 'on');
        set(S4, 'Checked', 'off');
        set(S6, 'Checked', 'off');
        set(S8, 'Checked', 'off');
        set(S10, 'Checked', 'off');
        set(SO, 'Checked', 'off');
    end
    function SHother (source,eventdata,handle)
        global duration
        fd = figure('Visible','on','Position',[900,800,100,50],'Name','Duration','NumberTitle','off',...
            'MenuBar','none',...
            'IntegerHandle','off',...
            'Units','normalized');
        hd = uicontrol('Parent',fd,'Style','edit','position',[15,10,80,15],'BackgroundColor','white','FontSize',10,'Callback',{@wduration});

        function wduration(source,eventdata,handle)

            duration= str2num(get(hd,'String'));
            set(SO,'Label',[num2str(duration) ' Sec']);
        end
        set(gcbo, 'Checked', 'on');
        set(S2, 'Checked', 'off');
        set(S4, 'Checked', 'off');
        set(S6, 'Checked', 'off');
        set(S8, 'Checked', 'off');
        set(S10, 'Checked', 'off');
    end

%% TXT FILE CHANNEL CHOSEN
    function ChannelChanged(hObject,eventdata)
        global chan
        chan=get(eventdata.NewValue,'String');
    end
%%
    function MagGlass(hObject,~)
        magnify;
    end
%% showtimemarks
    function showtimemarks(hObject,eventdata)
        global showmarks
        if  strcmp(get(gcbo,'Checked'),'off')
            set(gcbo, 'Checked', 'on');
            showmarks=1;
        else
            set(gcbo, 'Checked', 'off');
            showmarks=0;
        end
        resetbutton_Callback
    end

    function LynHasFeet(hObject,eventdata)
        A=imread('NeuroWeave-Landing-QR.png');
        hf=figure();
        %        set(gcf, 'Position', get(0,'Screensize'));
        set(hf, 'Units' ,'normalized','Position',[ 0.25 0.25 0.6 0.7 ],  'NumberTitle','off',...
            'MenuBar','none');
        [x,y]=meshgrid(linspace(0,1,600),linspace(0,1,600));
        purple=cat(3,0.10+0.28*x+0.08*y,0.03+0.05*x+0.02*y,0.18+0.30*x+0.16*y);
        hbg=axes('Parent',hf,'Position',[0 0 1 1]);
        image(hbg,purple);
        axis(hbg,'off');
        hqr=axes('Parent',hf,'Position',[0.28 0.12 0.44 0.76],'Color','white');
        image(hqr,A);
        axis(hqr,'image','off');
    end
    function txtstreamfile(hObject,eventdata)
        global data rate
        %    dirct = (get(hraw,'String'));
        %            dirct(dirct=='.')='_';
        %
        [FileName,PathName] = uiputfile2('Select file');
        dirct = [PathName FileName];
        if (dirct==0)
            return;
        end
        startsSec=get(hsecond,'string');
        lengthwin=get(hlength,'string');
        fid2=fopen( [dirct  'rate_'  num2str(rate)  '_st'  startsSec '_' lengthwin 'secs.txt' ],'w');
        % txtname=[dirct(1:end-60) 'rate_' num2str(rate) '_st'  startsSec '_' lengthwin 'secs.txt' ];
        %       fid2=fopen( txtname,'w');
        fprintf(fid2,'%f\n',data);
        fclose(fid2);
    end

    function close_Callback(hObject, ~, handles)
        global output all allfeat
        b=get(htable,'Data');
        if ~isempty(b{1,1})
            selection = questdlg('Do you want to save comments in the results file?',...
                'Close Request','Yes','No','Cancel','Cancel');
            if strcmp(selection, 'Cancel')
                return
            end
            if strcmp(selection, 'Yes')
                tags=b(:,3);
                adressR=get(hstarts,'String');
                [file,path] = uiputfile2('*.mat','Save results in');
                output = [path file];
                if ~isempty (output)
                    starts=b{:,1};
                    if ~exist('all')
                        all=[];
                        allfeat=[];
                    end
                    save(output,'b','starts','all','allfeat','tags');
                end

            end
        end
        delete(gcf); clc; clear all
    end



    function [txtdirct]=txt_file(dirct,PathName,FileName)
        global chan
        datdirct=dirct;
        datdirct(end-2:end)=['dat'];
        if ~strcmp(datdirct(end-8:end-4),'fixed') % text file has not been converted
            %FIX FORMAT
            txtfile=[PathName FileName(1:end-4) '_fixed'  FileName(end-3:end)];
            [s, msg] = replaceinfile( ',' , '.' , [dirct],txtfile);
        else
            txtfile=dirct;
        end
        fid1=fopen(txtfile);

        for j=1:5
            g{j}=fgets(fid1);
        end
        fclose(fid1);
        %how many channals

        cans=floor(( length(g{5})-7)/9);
        g{4}(1:14)=[];
        strl=  floor((length (g{4})-2)/cans);

        hf = figure(        'Toolbar','none',...
            'MenuBar','none',...
            'IntegerHandle','off',...
            'Units','normalized',...
            'Resize','off',...
            'NumberTitle','off',...
            'HandleVisibility','callback',...
            'Position',[0.4 0.4 0.35 0.4],...
            'Name',['Choose Channel']);
        % Create a Mode (Simulation or GRT) panel
        hbg = uibuttongroup('Parent',hf,...
            'Units','normalized',...
            'Position',[0.02 0.02 0.45 0.95],...
            'Title','Channels',...
            'BackgroundColor',get(hf,'Color'),...
            'HandleVisibility','callback',...
            'SelectionChangeFcn',@ChannelChanged,...
            'Tag','modeGroup');
        positions = [0.8 0.7 0.6  0.5  0.4  0.3  0.2 0.1];
        for p=1:cans
            %             strings{p} = ['Channel ' num2str(p)];

            strings{p}=g{4}((p-1)*strl+p:p*strl+p);
            tags{p}=['c' num2str(p)];
            %     enable = {'off','off','off','off','off','off','off','off'};
            enable{p} = ['on'];
        end
        % Also pop-up a dialog telling the user what's happening
        for idx = 1:length(strings)
            uicontrol('Parent',hbg,...
                'Style','radiobutton',...
                'Units','normalized',...
                'Position',[0.15 positions(idx) 0.4 0.09],...
                'String',strings{idx},...
                'Enable',enable{idx},...
                'Backgroundcolor',get(hf,'Color'),...
                'HandleVisibility','callback',...
                'Tag',tags{idx});
        end

        hbf = uibuttongroup('Parent',hf,...
            'Units','normalized',...
            'Position',[0.5 0.02 0.475 0.95],...
            'Title','!',...
            'BackgroundColor',get(hf,'Color'),...
            'HandleVisibility','callback');
        uicontrol('Parent',hbf,...
            'Style','text',...
            'Units','normalized',...
            'Position',[0.12 0.2 0.8 0.65],...
            'FontSize',10,...
            'String',['After you select the cannel and close this window, the signal from this channel will be reformatted and saved as:  ' datdirct] ,...
            'Enable',enable{idx},...
            'Backgroundcolor',get(hf,'Color'),...
            'HandleVisibility','callback',...
            'Tag',tags{idx});
        waitfor(hf);
        if isempty(chan);
            chan =strings{1};
            channel=1;
        else

            for p=1:cans
                if strcmp(strings{p},chan)
                    channel=p;
                end
            end
        end
        clear g
        datdirct=[  datdirct(1:end-4) '_' chan(1:strl)  '.dat'  ];
        fid2=fopen( [datdirct],'w');
        %             fid1=fopen([PathName 'temp' FileName]);

        % %   FOR PILO AND KI WITH DATA IN THE BEGINING

        %             chans=length(str2num(fgets(fid1)));

        k = 0;
        fid1=fopen(txtfile);
        t=0    ;
        while ~feof(fid1)
            if ~t
                for j=1:5
                    jk=fgets(fid1);
                end
                t=1;
            end
            data = fscanf(fid1,'%f',[cans+1,1]);%8 columns in txt file
            %                 if ~isempty(data);
            thischannel=data(channel+1,:);
            k = k+1;
            fwrite(fid2,thischannel,'float32' );%end
        end
        fclose(fid1);
        fclose(fid2);
        %             delete([PathName 'temp' FileName]);
        txtdirct=datdirct;
    end


    function [matdirct]=mat_file(dirct,PathName,FileName)
        datdirct=dirct;
        N=str2num(datdirct(end-7:end-5))
        % datdirct=[  datdirct(1:end-4)   '_Merged_200hz_.dat'  ];
        datdirct=[  datdirct(1:end-4)   '_Merged_h00hz_.dat'  ];

        names{1}=dirct;
        for n=N+1:N+80
            if n>9
                strn='0'
            else
                strn='00'
            end
            tempname=[ dirct(1:end-8) strn num2str(n) ').mat'];
            names=[ names tempname];
        end

        newfid=fopen( [datdirct],'w');
        % a=load('LP_fs400_fc100_order200.mat');
        a=load('LP_fs2000_fc100_order200.mat');
        b=load('HP_fs200_fc2_order200.mat');
        for n=1:length(names)
            if exist(names{n})
                matdata=load(names{n},'data');
                %             matdata.data=filtfilt(a.LP_fs400_fc100_order200,1,matdata.data);%filter 100
                matdata.data=filtfilt(a.LP_fs2000_fc100_order200,1,matdata.data);%filter 100
                matdata.data=downsample(matdata.data,10);
                matdata.data=filtfilt(b.HP_fs200_fc2_order200,1,matdata.data);%filter 100


                fwrite(newfid,matdata.data,'float32' );%end
            end
        end

        fclose(newfid);
        matdirct=datdirct;
    end


    function FeatMenu (source,eventdata,handle)
        global   numberfeatures UseFeats
        hparent=get(gcbo,'Parent');
        if (hparent==hF)
            if isempty(UseFeats)
                UseFeats=zeros(1,26);end
            if strcmp(get(gcbo,'Checked'),'on')
                set(gcbo, 'Checked', 'off');
                UseFeats(get(gcbo,'Position'))=0;
            else
                set(gcbo, 'Checked', 'on');
                UseFeats(get(gcbo,'Position'))=1;
            end
        else
            if numberfeatures==1
                UseFeats=zeros(1,26);
                for fi=1:26
                    set(Fhands{ fi  }, 'Checked', 'off');
                end
                clear fi
                UseFeats([ 1 3  4 21 22 ])=1;
                set(Fhands{ 1  }, 'Checked', 'on');
                set(Fhands{  3  }, 'Checked', 'on');
                set(Fhands{   4  }, 'Checked', 'on');
                set(Fhands{  21  }, 'Checked', 'on');
                set(Fhands{  22 }, 'Checked', 'on');


            else
                UseFeats=ones(1,26);
                for fi=1:26
                    set(Fhands{ fi  }, 'Checked', 'on');
                end
                clear fi
                %             set(Fhands{  3  }, 'Checked', 'on');
                %             set(Fhands{   4  }, 'Checked', 'on');
                %             set(Fhands{  21  }, 'Checked', 'on');
                %             set(Fhands{  22 }, 'Checked', 'on');
            end
        end

    end
    function M11(source,eventdata,handle)
        global interval
        interval= 1;
        set(gcbo, 'Checked', 'on');
        set(M2, 'Checked', 'off');
        set(M3, 'Checked', 'off');
        set(M4, 'Checked', 'off');
    end

    function M22(source,eventdata,handle)
        global interval
        interval= 2;
        set(gcbo, 'Checked', 'on');
        set(M1, 'Checked', 'off');
        set(M3, 'Checked', 'off');
        set(M4, 'Checked', 'off');
    end

    function M33(source,eventdata,handle)
        global interval
        interval= 3;
        set(gcbo, 'Checked', 'on');
        set(M1, 'Checked', 'off');
        set(M2, 'Checked', 'off');
        set(M4, 'Checked', 'off');
    end
    function M44(source,eventdata,handle)
        global interval
        interval= 5;
        set(gcbo, 'Checked', 'on');
        set(M1, 'Checked', 'off');
        set(M2, 'Checked', 'off');
        set(M3, 'Checked', 'off');
    end

end
