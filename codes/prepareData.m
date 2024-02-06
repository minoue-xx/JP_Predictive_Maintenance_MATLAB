% Copyright 2016-2024 The MathWorks, Inc.
% 下記URLで公開されているデータをダウンロードし、
% Data Set FD001をエンジン毎にcsvファイルとして分離して使用します。
% https://www.nasa.gov/intelligent-systems-division/discovery-and-systems-health/pcoe/pcoe-data-set-repository/
% 6. Turbofan Engine Degradation Simulation
% Download: https://data.nasa.gov/Aeorspace/CMAPSS-Jet-Engine-Simulated-Data/ff5v-kuh6  
% Download Mirror: https://phm-datasets.s3.amazonaws.com/NASA/6.+Turbofan+Engine+Degradation+Simulation+Data+Set.zip
% Data Set Citation: A. Saxena and K. Goebel (2008). “Turbofan Engine Degradation Simulation Data Set”, NASA Prognostics Data Repository, NASA Ames Research Center, Moffett Field, CA
%
%  Data Set: FD001
% * Train trjectories: 100
% * Conditions: ONE (Sea Level)
% * Fault Modes: ONE (HPC Degradation)
%
% References:
% * A. Saxena, K. Goebel, D. Simon, and N. Eklund, Damage Propagation Modeling for Aircraft Engine Run-to-Failure Simulation 
% in the Proceedings of the 1st International Conference on Prognostics and Health Management (PHM08), Denver CO, Oct 2008.


% 今回使用するデータファイル(CMAPSSData.zip)を下記URLからダウンロードし、
% OriginalDataSetフォルダに展開します。
originalFile = 'originalDataSet\CMAPSSData.zip';
dataDir = 'originalDataSet';
if ~exist(dataDir,'dir')
    mkdir(dataDir);
end
if ~exist(originalFile, 'file') % download only once
    disp("Downloading 12MB data set... this might take a while");
    disp(newline + "nDownload of the original dataset in progress..." + newline + ...
        "Please allow the download of the .zip file to complete before proceeding." + newline);
    datafile = websave(originalFile,'https://data.nasa.gov/download/ff5v-kuh6/application%2Fzip');
    disp(newline + "Download Complete: Press any key to proceed")
    pause
end

% 上記ステップが正常に機能しない場合は Webブラウザ から直接
% https://data.nasa.gov/Aeorspace/CMAPSS-Jet-Engine-Simulated-Data/ff5v-kuh6
% にアクセスし、CMAPSSData.zip をダウンロードできます。
% 本スクリプト (prepareData.m) が存在するフォルダ化に
% originalDataSet という名前のフォルダを作成し、その中に CMAPSSData.zip を保存してください。

% その後下記を実行してください。
unzip(originalFile, dataDir);
disp(['Data is unziped to the directory: ', dataDir, '.']);

%% train_FD001.txtのデータを、エンジンごとに分割します。
outputFolder = 'originalDataSet';
File = fullfile(outputFolder,'train_FD001.txt');
data = dlmread(File);

% 変数名作成 
varNames = {'Unit', 'Time', 'Setting1', 'Setting2', 'Setting3', 'FanInletTemp',...
    'LPCOutletTemp', 'HPCOutletTemp', 'LPTOutletTemp', 'FanInletPres', ...
    'BypassDuctPres', 'TotalHPCOutletPres', 'PhysFanSpeed', 'PhysCoreSpeed', ...
    'EnginePresRatio', 'StaticHPCOutletPres', 'FuelFlowRatio', 'CorrFanSpeed', ...
    'CorrCoreSpeed', 'BypassRatio', 'BurnerFuelAirRatio', 'BleedEnthalpy', ...
    'DemandFanSpeed', 'DemandCorrFanSpeed', 'HPTCoolantBleed', 'LPTCoolantBleed'};
dataSet = array2table(data,'VariableNames',varNames);

if ~exist('dataSet', 'dir') 
    disp('Created a new folder "dataSet"');
    mkdir('dataSet');
end

% エンジンの数だけ、csv への出力を繰り返します。
NofEngine = length(unique(dataSet.Unit));
for ii = 1:NofEngine
    idx = dataSet.Unit == ii;
    filename = ['dataSet\train_FD001_Unit_', num2str(ii), '.csv'];
    writetable(dataSet(idx,:),filename);
end

%% デモの後半で読み込む mat ファイルの準備
% （UnsupervisedLive_JP.mlx 内で適応するノイズ除去の処理実行）
tmp = dataSet;
dataSet = [];
for ii = 1:NofEngine
    tempData = tmp(tmp.Unit == ii,:);
    tempData{:,3:end} = movmean(tempData{:,3:end}, 5);
    dataSet = [dataSet;tempData(5:end,:)]; %#ok<AGROW>
end

% 故障まで残されたフライト数
% splitapply で 各Unitのそれぞれのデータに対して x-max(x) を適用します。
TimeToFail = splitapply(@(x) {x-max(x)},dataSet.Time,dataSet.Unit);
dataSet.TimeToFail = cat(1,TimeToFail{:});

% 上記２行と同じ処理は for ループを使用した下記と同じ処理です。
% dataSet.TimeToFail = zeros(height(dataSet),1);　
% FailedTime = splitapply(@max,dataSet.Time,dataSet.Unit); % 各エンジンの故障時点のフライト数
% for ii = 1:NofEngine
%     idx = dataSet.Unit == ii;
%     dataSet.TimeToFail(idx) = dataSet.Time(idx) - FailedTime(ii); 
% end

% 処理に使用する変数だけを fullDataset.mat に保存
variableNames = {'Unit' 'Time' 'LPCOutletTemp' 'HPCOutletTemp', 'LPTOutletTemp' 'TotalHPCOutletPres' 'PhysFanSpeed' ...
    'PhysCoreSpeed' 'StaticHPCOutletPres' 'FuelFlowRatio', 'CorrFanSpeed' 'CorrCoreSpeed' 'BypassRatio'...
    'BleedEnthalpy' 'HPTCoolantBleed' 'LPTCoolantBleed','TimeToFail'};
fullDataset = dataSet(:,variableNames);
save('fullDataset.mat','fullDataset')

disp('Data Set for case 1 (UnsupervisedLive_JP.mlx) demo is ready.');

%% ClassificationLive_JP.mlx 用のデータを用意します。
% こちらでは Time を故障までに残されたフライト数 TimeToFail で置き換えます。
fullDataset.Time = fullDataset.TimeToFail;
variableNames = {'Unit' 'Time' 'LPCOutletTemp' 'HPCOutletTemp', 'LPTOutletTemp' 'TotalHPCOutletPres' 'PhysFanSpeed' ...
    'PhysCoreSpeed' 'StaticHPCOutletPres' 'FuelFlowRatio', 'CorrFanSpeed' 'CorrCoreSpeed' 'BypassRatio'...
    'BleedEnthalpy' 'HPTCoolantBleed' 'LPTCoolantBleed'};
fullDataset = fullDataset(:,variableNames);
save('classificationData.mat','fullDataset')

disp('Data Set for case 2 (CassificationLive_JP.mlx) demo is ready.');
%%
clear
