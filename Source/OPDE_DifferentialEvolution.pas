unit OPDE_DifferentialEvolution;

////////////////////////////////////////////////////////////////////////////////
//                                                                           //
// Version: MPL 1.1 or LGPL 2.1 with linking exception                       //
//                                                                           //
// The contents of this file are subject to the Mozilla Public License       //
// Version 1.1 (the "License"); you may not use this file except in          //
// compliance with the License. You may obtain a copy of the License at      //
// http://www.mozilla.org/MPL/                                               //
//                                                                           //
// Software distributed under the License is distributed on an "AS IS"       //
// basis, WITHOUT WARRANTY OF ANY KIND, either express or implied. See the   //
// License for the specific language governing rights and limitations under  //
// the License.                                                              //
//                                                                           //
// Alternatively, the contents of this file may be used under the terms of   //
// the Free Pascal modified version of the GNU Lesser General Public         //
// License Version 2.1 (the "FPC modified LGPL License"), in which case the  //
// provisions of this license are applicable instead of those above.         //
// Please see the file LICENSE.txt for additional information concerning     //
// this license.                                                             //
//                                                                           //
// The code is part of the Object Pascal Differential Evolution Project      //
//                                                                           //
// Portions created by Christian-W. Budde are Copyright (C) 2006-2011        //
// by Christian-W. Budde. All Rights Reserved.                               //
//                                                                           //
////////////////////////////////////////////////////////////////////////////////

interface

{$I jedi.inc}

{-$DEFINE StartStopExceptions}

uses
  Types, Classes, SysUtils, SyncObjs, OPDE_Chunks;

type
  EDifferentialEvolution = class(Exception);

  DoubleArray = array [0 .. $0FFFFFF8] of Double;
  PDoubleArray = ^DoubleArray;

  TNewDifferentialEvolution = class;

  TDECalculateCostEvent = function(Sender: TObject; Data: PDoubleArray;
    Count: Integer): Double of object;
  TDEBestCostChangedEvent = procedure(Sender: TObject;
    BestCost: Double) of object;
  TDEGenerationChangedEvent = procedure(Sender: TObject;
    Generation: Integer) of object;
  TDEUpdateGains = (ugNone, ugPerGeneration, ugAlways);

  TDEVariableCollectionItem = class(TCollectionItem)
  private
    FDisplayName : string;
    FMinimum     : Double;
    FMaximum     : Double;
    procedure SetMaximum(const Value: Double);
    procedure SetMinimum(const Value: Double);
  protected
    function GetDisplayName: string; override;
    procedure SetDisplayName(const Value: string); override;
    procedure AssignTo(Dest: TPersistent); override;

    procedure MaximumChanged; virtual;
    procedure MinimumChanged; virtual;
  public
    constructor Create(Collection: TCollection); override;
  published
    property DisplayName;
    property Minimum: Double read FMinimum write SetMinimum;
    property Maximum: Double read FMaximum write SetMaximum;
  end;

  TDEVariableCollection = class(TOwnedCollection)
  protected
    function GetItem(Index: Integer): TDEVariableCollectionItem; virtual;
    procedure SetItem(Index: Integer;
      const Value: TDEVariableCollectionItem); virtual;
    procedure Update(Item: TCollectionItem); override;
    property Items[Index: Integer]: TDEVariableCollectionItem
      read GetItem write SetItem; default;
  public
    constructor Create(AOwner: TComponent);
  end;

  TDEPopulationData = class(TPersistent)
  private
    FDE    : TNewDifferentialEvolution;
    FData  : PDoubleArray;
    FCount : Cardinal;
    FCost  : Double;
    function GetData(Index: Cardinal): Double;
    procedure SetData(Index: Cardinal; const Value: Double);
  protected
    procedure AssignTo(Dest: TPersistent); override;
    property DifferentialEvolution: TNewDifferentialEvolution read FDE;
  public
    constructor Create(DifferentialEvaluation: TNewDifferentialEvolution); overload;
    destructor Destroy; override;

    procedure InitializeData;

    property Cost: Double read FCost write FCost;
    property Data[Index: Cardinal]: Double read GetData write SetData;
    property DataPointer: PDoubleArray read FData;
    property Count: Cardinal read FCount;
  end;

  TDECalculateGenerationCosts = procedure(Generation: PPointerArray) of object;

  TNewDifferentialEvolution = class(TComponent)
  strict private
    FCrossOver           : Double;
    FDifferentialWeight  : Double;
    FBestWeight          : Double;
    FGains               : array [0..2] of Double;
    FGainBest            : Double;
    FVariables           : TDEVariableCollection;
    FOnCalculateCosts    : TDECalculateCostEvent;
    FOnBestCostChanged   : TDEBestCostChangedEvent;
    FOnGenerationChanged : TDEGenerationChangedEvent;
    FCalcGenerationCosts : TDECalculateGenerationCosts;
    FDirectSelection     : Boolean;
    FUpdateInternalGains : TDEUpdateGains;
    FJitterGains         : PDoubleArray;
    function GetIsRunning: Boolean;
    function GetNumberOfThreads: Cardinal;
    procedure SetBestWeight(const Value: Double);
    procedure SetCrossOver(const Value: Double);
    procedure SetDifferentialWeight(const Value: Double);
    procedure SetDirectSelection(const Value: Boolean);
    procedure SetNumberOfThreads(const Value: Cardinal);
    procedure SetPopulationCount(const Value: Cardinal);
    procedure SetVariables(const Value: TDEVariableCollection);
    procedure SetDither(const Value: Double);
    procedure SetDitherPerGeneration(const Value: Boolean);
    procedure SetJitter(const Value: Double);
    procedure SetBestPopulation(const Value: TDEPopulationData);
  private
    FBestPopulation         : TDEPopulationData;
    FTotalGenerations       : Integer;
    FCurrentGenerationIndex : Integer;
    FCurrentPopulationIndex : Cardinal;
    FPopulationsCalculated  : Cardinal;
    FPopulationCount        : Cardinal;
    FIsInitialized          : Boolean;
    FDriverThread           : TThread;
    FCostCalculationEvent   : TEvent;
    FCriticalSection        : TCriticalSection;
    FThreads                : array of TThread;
    FDither                 : Double;
    FDitherPerGeneration    : Boolean;
    FJitter                 : Double;
    FUseJitter              : Boolean;
    procedure CreatePopulationData;
    procedure FreePopulationData;
    procedure FindDifferentPopulations(const Current: Integer; out A: Integer); overload;
    procedure FindDifferentPopulations(const Current: Integer; out A, B: Integer); overload;
    procedure FindDifferentPopulations(const Current: Integer; out A, B, C: Integer); overload;
    procedure FindDifferentPopulations(const Current: Integer; out A, B, C, D: Integer); overload;
    function FindBest(Generation: PPointerArray): TDEPopulationData;
    function CalculateJitter(VariableIndex: Integer): Double;
    procedure BuildNextGeneration;
    procedure CalculateCostsDirect(Generation: PPointerArray);
    procedure CalculateCostsThreaded(Generation: PPointerArray);
    procedure CheckUpdateInternalGains;
    procedure RandomizePopulation;
    procedure SelectFittest;
    procedure UpdateInternalGains;
    procedure UpdateJitterGains;
    procedure InitializeData;
    function GetCurrentPopulation(Index: Cardinal): TDEPopulationData;
  protected
    FVariableCount     : Cardinal;
    FCurrentPopulation : PPointerArray;
    FNextPopulation    : PPointerArray;
    procedure BestWeightChanged; virtual;
    procedure BestPopulationChanged; virtual;
    procedure CrossoverChanged; virtual;
    procedure DifferentialWeightChanged; virtual;
    procedure DirectSelectionChanged; virtual;
    procedure DitherChanged; virtual;
    procedure DitherPerGenerationChanged; virtual;
    procedure GenerationChanged; virtual;
    procedure JitterChanged; virtual;
    procedure PopulationCountChanged; virtual;
    procedure NumberOfThreadsChanged; virtual;
    procedure VariableChanged(Index: Integer); virtual;
    procedure VariableCountChanged; virtual;

    procedure CalculateCurrentGeneration;
    procedure AssignTo(Dest: TPersistent); override;

    property VariableCount: Cardinal read FVariableCount;
    property IsInitialized: Boolean read FIsInitialized;
  public
    constructor Create(AOwner: TComponent); override;
    destructor Destroy; override;

    procedure Start(Evaluations: Integer = 0);
    procedure Stop;
    procedure Reset;

    procedure Evolve;

    procedure SaveToFile(FileName: TFileName);
    procedure LoadFromFile(FileName: TFileName);
    procedure SaveToStream(Stream: TStream);
    procedure LoadFromStream(Stream: TStream);

    property BestPopulation: TDEPopulationData read FBestPopulation write SetBestPopulation;
    property CurrentPopulation[Index: Cardinal]: TDEPopulationData read GetCurrentPopulation;
    property IsRunning: Boolean read GetIsRunning;
    property CurrentGeneration: Integer read FCurrentGenerationIndex write FCurrentGenerationIndex;
  published
    property BestWeight: Double read FBestWeight write SetBestWeight;
    property CrossOver: Double read FCrossOver write SetCrossOver;
    property Dither: Double read FDither write SetDither;
    property DitherPerGeneration: Boolean read FDitherPerGeneration write SetDitherPerGeneration default True;
    property DifferentialWeight: Double read FDifferentialWeight write SetDifferentialWeight;
    property DirectSelection: Boolean read FDirectSelection write SetDirectSelection default False;
    property Jitter: Double read FJitter write SetJitter;
    property NumberOfThreads: Cardinal read GetNumberOfThreads write SetNumberOfThreads default 0;
    property PopulationCount: Cardinal read FPopulationCount write SetPopulationCount default 15;
    property Variables: TDEVariableCollection read FVariables write SetVariables;
    property OnCalculateCosts: TDECalculateCostEvent read FOnCalculateCosts write FOnCalculateCosts;
    property OnBestCostChanged: TDEBestCostChangedEvent read FOnBestCostChanged write FOnBestCostChanged;
    property OnGenerationChanged: TDEGenerationChangedEvent read FOnGenerationChanged write FOnGenerationChanged;
  end;

procedure Register;

implementation

uses
  Math;

resourcestring
  RCStrCrossOverBoundError = 'CrossOver must be 0 <= x <= 1';
  RCStrDiffWeightBoundError = 'Differential Weight must be 0 <= x <= 2';
  RCStrBestWeightBoundError = 'Best Weight must be 0 <= x <= 2';
  RCStrPopulationCountError = 'At least 4 populations are required!';
  RCStrIndexOutOfBounds = 'Index out of bounds (%d)';
  RCStrOptimizerIsAlreadyRunning = 'Optimizer is already running';
  RCStrOptimizerIsRunning = 'Optimizer is running';
  RCStrOptimizerIsNotRunning = 'Optimizer is not running';
  RCStrNoCostFunction = 'No cost function specified!';
  RCStrReferenceMismatch = 'Reference mismatch';

type
  TDriverThread = class(TThread)
  protected
    FOwner: TNewDifferentialEvolution;
    procedure Execute; override;
  public
    constructor Create(Owner: TNewDifferentialEvolution); virtual;
  end;

  TCostCalculatorThread = class(TThread)
  protected
    FOwner      : TNewDifferentialEvolution;
    FGeneration : PPointerArray;
    procedure Execute; override;
  public
    constructor Create(Owner: TNewDifferentialEvolution;
      Generation: PPointerArray); virtual;
  end;


{ TDriverThread }

constructor TDriverThread.Create(Owner: TNewDifferentialEvolution);
begin
  FOwner := Owner;
  inherited Create(False);
end;

procedure TDriverThread.Execute;
begin
  inherited;

  while not Terminated do
  begin
    FOwner.CalculateCurrentGeneration;

    Synchronize(FOwner.GenerationChanged);

    Inc(FOwner.FCurrentGenerationIndex);
    if (FOwner.FTotalGenerations > 0) and (FOwner.FCurrentGenerationIndex >= FOwner.FTotalGenerations) then
    begin
      FreeOnTerminate := True;
      Terminate;
      FOwner.FDriverThread := nil;
    end;
  end;
end;


{ TCostCalculatorThread }

constructor TCostCalculatorThread.Create(Owner: TNewDifferentialEvolution;
  Generation: PPointerArray);
begin
  FOwner := Owner;
  FGeneration := Generation;
  inherited Create(False);
end;

procedure TCostCalculatorThread.Execute;
var
  Population : Cardinal;
begin
  inherited;

  while not Terminated do
    with FOwner do
    begin
      FCriticalSection.Enter;
      try
        Population := FCurrentPopulationIndex;
        if Population >= PopulationCount then
        begin
          Terminate;
          Exit;
        end;
        Inc(FCurrentPopulation);
      finally
        FCriticalSection.Leave;
      end;

      Assert(Population < PopulationCount);

      with TDEPopulationData(FGeneration^[Population]) do
        FCost := OnCalculateCosts(Self, FData, VariableCount);

      FCriticalSection.Enter;
      try
        Inc(FPopulationsCalculated);
      finally
        FCriticalSection.Leave;
      end;

      if FOwner.FPopulationsCalculated = FOwner.PopulationCount then
      begin
        FCostCalculationEvent.SetEvent;
        Terminate;
      end;
      Assert(FPopulationsCalculated <= FOwner.PopulationCount);
    end;
end;


{ TDEVariableCollectionItem }

constructor TDEVariableCollectionItem.Create
  (Collection: TCollection);
begin
  inherited;
  FDisplayName := 'Variable ' + IntToStr(Index);
  FMinimum := 0;
  FMaximum := 1;
end;

procedure TDEVariableCollectionItem.AssignTo
  (Dest: TPersistent);
begin
  if Dest is TDEVariableCollectionItem then
    with TDEVariableCollectionItem(Dest) do
    begin
      FDisplayName := Self.FDisplayName;
      FMinimum := Self.FMinimum;
      FMaximum := Self.FMaximum;
    end
  else
    inherited;
end;

procedure TDEVariableCollectionItem.MaximumChanged;
begin
  Changed(False);
  (*
    Assert(Collection.Owner is TNewDifferentialEvolution);
    TNewDifferentialEvolution(Collection.Owner).VariableChanged(Index);
    Collection.EndUpdate;
  *)
end;

procedure TDEVariableCollectionItem.MinimumChanged;
begin
  Changed(False);
  (*
    Assert(Collection.Owner is TNewDifferentialEvolution);
    TNewDifferentialEvolution(Collection.Owner).VariableChanged(Index);
  *)
end;

function TDEVariableCollectionItem.GetDisplayName: string;
begin
  Result := FDisplayName;
end;

procedure TDEVariableCollectionItem.SetDisplayName
  (const Value: string);
begin
  FDisplayName := Value;
  inherited;
end;

procedure TDEVariableCollectionItem.SetMaximum
  (const Value: Double);
begin
  if FMaximum <> Value then
  begin
    FMaximum := Value;
    MaximumChanged;
  end;
end;

procedure TDEVariableCollectionItem.SetMinimum
  (const Value: Double);
begin
  if FMinimum <> Value then
  begin
    FMinimum := Value;
    MinimumChanged;
  end;
end;


{ TDEVariableCollection }

constructor TDEVariableCollection.Create(AOwner: TComponent);
begin
  inherited Create(AOwner, TDEVariableCollectionItem);
end;

function TDEVariableCollection.GetItem(Index: Integer)
  : TDEVariableCollectionItem;
begin
  Result := TDEVariableCollectionItem
    (inherited GetItem(Index));
end;

procedure TDEVariableCollection.SetItem(Index: Integer;
  const Value: TDEVariableCollectionItem);
begin
  inherited SetItem(Index, Value);
end;

procedure TDEVariableCollection.Update
  (Item: TCollectionItem);
begin
  inherited;

  if (Owner is TNewDifferentialEvolution) then
    if Assigned(Item) then
      TNewDifferentialEvolution(Owner).VariableChanged(Item.Index)
    else
      TNewDifferentialEvolution(Owner).VariableCountChanged;
end;


{ TDEPopulationData }

constructor TDEPopulationData.Create(
  DifferentialEvaluation: TNewDifferentialEvolution);
begin
  FDE := DifferentialEvaluation;
  FCount := FDE.VariableCount;
  GetMem(FData, FCount * SizeOf(Double));
end;

destructor TDEPopulationData.Destroy;
begin
  FreeMem(FData);
  inherited;
end;

procedure TDEPopulationData.AssignTo(Dest: TPersistent);
begin
  if Dest is TDEPopulationData then
    with TDEPopulationData(Dest) do
    begin
      if not (FDE = Self.FDE) then
        raise Exception.Create(RCStrReferenceMismatch);
      Assert(Count = Self.Count);
      Move(Self.FData, FData, Self.Count * SizeOf(Double));
      FCost  := Self.FCost;
    end
  else
    inherited;
end;

procedure TDEPopulationData.InitializeData;
var
  Index  : Integer;
  Offset : Double;
  Scale  : Double;
begin
  Assert(FCount = FDE.VariableCount);

  for Index := 0 to FCount - 1 do
    with FDE.Variables[Index] do
    begin
      Offset := Minimum;
      Scale := Maximum - Minimum;
      FData[Index] := Offset + Random * Scale;
    end;
end;

function TDEPopulationData.GetData(Index: Cardinal): Double;
begin
  if (Index <= FCount) then
    Result := FData^[Index]
  else
    raise Exception.CreateFmt(RCStrIndexOutOfBounds, [Index]);
end;

procedure TDEPopulationData.SetData(Index: Cardinal; const Value: Double);
begin
  if (Index <= FCount) then
    if FData^[Index] <> Value then
    begin
      FData^[Index] := Value;

      // TODO: recalculate costs
    end
    else
  else
    raise Exception.CreateFmt(RCStrIndexOutOfBounds, [Index]);
end;


{ TNewDifferentialEvolution }

constructor TNewDifferentialEvolution.Create(AOwner: TComponent);
begin
  inherited;
  FVariables := TDEVariableCollection.Create(Self);

  FPopulationCount := 15;
  FDirectSelection := False;
  FIsInitialized := False;
  FBestWeight := 0;
  FCrossOver := 0.9;
  FDifferentialWeight := 0.4;
  FCalcGenerationCosts := CalculateCostsDirect;
  FTotalGenerations := 0;
  FCurrentGenerationIndex := 0;
  FUseJitter := False;
  FDitherPerGeneration := True;
  FBestPopulation := nil;

  UpdateInternalGains;
end;

destructor TNewDifferentialEvolution.Destroy;
begin
  if IsRunning then
    Stop;

  // eventually free cost calculation event
  if Assigned(FCostCalculationEvent) then
    FreeAndNil(FCostCalculationEvent);

  if Assigned(FCriticalSection) then
    FreeAndNil(FCriticalSection);

  FreePopulationData;
  FreeAndNil(FVariables);

  if Assigned(FJitterGains) then
    FreeMem(FJitterGains);

  inherited;
end;

procedure TNewDifferentialEvolution.CreatePopulationData;
var
  Index: Integer;
begin
  // allocated memory
  GetMem(FCurrentPopulation, FPopulationCount * SizeOf(TDEPopulationData));
  GetMem(FNextPopulation, FPopulationCount * SizeOf(TDEPopulationData));

  // actually create population data
  for Index := 0 to FPopulationCount - 1 do
  begin
    FCurrentPopulation[Index] := TDEPopulationData.Create(Self);
    FNextPopulation[Index] := TDEPopulationData.Create(Self);
  end;
end;

procedure TNewDifferentialEvolution.FreePopulationData;
var
  Index: Integer;
begin
  // check whether memory has been allocated at all
  if not(Assigned(FCurrentPopulation) and Assigned(FNextPopulation)) then
    Exit;

  // free population data
  for Index := 0 to FPopulationCount - 1 do
  begin
    TDEPopulationData(FCurrentPopulation[Index]).Free;
    TDEPopulationData(FNextPopulation[Index]).Free;
  end;

  // free memory
  FreeMem(FCurrentPopulation, FPopulationCount * SizeOf(TDEPopulationData));
  FreeMem(FNextPopulation, FPopulationCount * SizeOf(TDEPopulationData));

  FCurrentPopulation := nil;
  FNextPopulation := nil;
end;

procedure TNewDifferentialEvolution.Start(Evaluations: Integer);
begin
  if IsRunning then
    raise EDifferentialEvolution.Create(RCStrOptimizerIsAlreadyRunning);

  if not Assigned(FOnCalculateCosts) then
    raise EDifferentialEvolution.Create(RCStrNoCostFunction);

  FTotalGenerations := FTotalGenerations + Evaluations;

  // create population data
  if not Assigned(FCurrentPopulation) then
    CreatePopulationData;

  // start driver thread
  if not Assigned(FDriverThread) then
    FDriverThread := TDriverThread.Create(Self);
end;

procedure TNewDifferentialEvolution.Stop;
begin
  {$IFDEF StartStopExceptions}
  if not IsRunning then
    raise EDifferentialEvolution.Create(RCStrOptimizerIsNotRunning);
  {$ENDIF}

  if Assigned(FDriverThread) then
  begin
    FDriverThread.Terminate;
    FDriverThread.WaitFor;
    FreeAndNil(FDriverThread);
  end;
end;

procedure TNewDifferentialEvolution.Reset;
begin
  if not IsRunning then
  begin
    FTotalGenerations := 0;
    FreePopulationData;
    FBestPopulation := nil;
  end
  else
    FTotalGenerations := FTotalGenerations - FCurrentGenerationIndex;

  FCurrentGenerationIndex := 0;
  FIsInitialized := False;
end;

procedure TNewDifferentialEvolution.Evolve;
begin
  {$IFDEF StartStopExceptions}
  if IsRunning then
    raise EDifferentialEvolution.Create(RCStrOptimizerIsRunning);
  {$ENDIF}

  // create population data
  if not Assigned(FCurrentPopulation) then
    CreatePopulationData;

  CalculateCurrentGeneration;
  Inc(FCurrentGenerationIndex);
end;

procedure TNewDifferentialEvolution.SaveToFile(FileName: TFileName);
var
  FileStream : TFileStream;
begin
  FileStream := TFileStream.Create(FileName, fmCreate);
  try
    SaveToStream(FileStream);
  finally
    FreeAndNil(FileStream);
  end;
end;

procedure TNewDifferentialEvolution.LoadFromFile(FileName: TFileName);
var
  FileStream : TFileStream;
begin
  FileStream := TFileStream.Create(FileName, fmOpenRead);
  try
    LoadFromStream(FileStream);
  finally
    FreeAndNil(FileStream);
  end;
end;

procedure TNewDifferentialEvolution.AssignTo(Dest: TPersistent);
begin
  if Dest is TChunkDifferentialEvolutionHeader then
    with TChunkDifferentialEvolutionHeader(Dest) do
    begin
      Jitter             := Self.FJitter;
      BestWeight         := Self.FBestWeight;
      Dither             := Self.FDither;
      PopulationCount    := Self.FPopulationCount;
      CrossOver          := Self.FCrossOver;
      DifferentialWeight := Self.FDifferentialWeight;
      CurrentGeneration  := Self.FCurrentGenerationIndex;
    end
  else
  if Dest is TNewDifferentialEvolution then
    with TNewDifferentialEvolution(Dest) do
    begin
      FJitter             := Self.FJitter;
      FBestWeight         := Self.FBestWeight;
      FDither             := Self.FDither;
      FPopulationCount    := Self.FPopulationCount;
      FCrossOver          := Self.FCrossOver;
      FDifferentialWeight := Self.FDifferentialWeight;
      FCurrentGenerationIndex  := Self.FCurrentGenerationIndex;
      NumberOfThreads     := Self.NumberOfThreads;
    end
  else
    inherited;
end;

procedure TNewDifferentialEvolution.SaveToStream(Stream: TStream);
var
  Header: TChunkDifferentialEvolutionHeader;
  PopulationIndex: Integer;
  ParameterIndex: Integer;
  Parameter: Double;
begin
  Header := TChunkDifferentialEvolutionHeader.Create;
  try
    Header.Assign(Self);

    Header.WriteToStream(Stream);

    for PopulationIndex := 0 to PopulationCount - 1 do
      with CurrentPopulation[PopulationIndex] do
        for ParameterIndex := 0 to Count - 1 do
        begin
          Parameter := Data[ParameterIndex];
          Stream.Write(Parameter, SizeOf(Double));
        end;
  finally
    Header.Free;
  end;
end;

procedure TNewDifferentialEvolution.LoadFromStream(Stream: TStream);
var
  ChunkName: TChunkName;
  ChunkSize: Cardinal;
  PopulationIndex: Integer;
  ParameterIndex: Integer;
  Parameter: Double;
  Header: TChunkDifferentialEvolutionHeader;
begin
  with Stream do
    while Position < Size do
    begin
      // read chunk name
      Read(ChunkName.AsUInt32, SizeOf(TChunkName));

      // read chunk size
      Read(ChunkSize, SizeOf(Cardinal));

      if ChunkName.AsChar8 = 'DEhd' then
      begin
        Header := TChunkDifferentialEvolutionHeader.Create;
        try
          // read header
          Header.ReadFromStream(Stream, ChunkSize);
          Self.Assign(Header);
        finally
          Header.Free;
        end
      end
      else
        Seek(ChunkSize, soFromCurrent);

      // create population data
      if not Assigned(FCurrentPopulation) then
        CreatePopulationData;

      for PopulationIndex := 0 to PopulationCount - 1 do
        with CurrentPopulation[PopulationIndex] do
          for ParameterIndex := 0 to Count - 1 do
          begin
            Stream.Read(Parameter, SizeOf(Double));
            Data[ParameterIndex] := Parameter;
          end;

      FCalcGenerationCosts(FCurrentPopulation);
      BestPopulation := FindBest(FCurrentPopulation);
      FIsInitialized := True;
    end;
end;

procedure TNewDifferentialEvolution.RandomizePopulation;
var
  Index : Integer;
begin
  for Index := 0 to FPopulationCount - 1 do
    TDEPopulationData(FCurrentPopulation[Index]).InitializeData;
end;

procedure TNewDifferentialEvolution.InitializeData;
begin
  RandomizePopulation;
  FCalcGenerationCosts(FCurrentPopulation);

  BestPopulation := FindBest(FCurrentPopulation);

  FIsInitialized := True;
end;

procedure TNewDifferentialEvolution.CalculateCostsDirect(Generation: PPointerArray);
var
  Index : Integer;
begin
  for Index := 0 to FPopulationCount - 1 do
    with TDEPopulationData(Generation^[Index]) do
      FCost := FOnCalculateCosts(Self, FData, VariableCount);
end;

procedure TNewDifferentialEvolution.CalculateCostsThreaded(
  Generation: PPointerArray);
var
  Index : Integer;
begin
  FCurrentPopulationIndex := 0;
  FPopulationsCalculated := 0;

  for Index := 0 to Length(FThreads) - 1 do
    FThreads[Index] := TCostCalculatorThread.Create(Self, Generation);

  if FCostCalculationEvent.WaitFor(INFINITE) <> wrSignaled then
    raise EDifferentialEvolution.Create('Error receiving signal');

  for Index := 0 to Length(FThreads) - 1 do
  begin
    FThreads[Index].WaitFor;
    FreeAndNil(FThreads[Index]);
  end;

  FCostCalculationEvent.ResetEvent;

  if FPopulationsCalculated <> FPopulationCount then
    Assert(FPopulationsCalculated = FPopulationCount);
end;

procedure TNewDifferentialEvolution.FindDifferentPopulations(
  const Current: Integer; out A: Integer);
begin
  repeat
    A := Random(FPopulationCount);
  until (A <> Current) and (FCurrentPopulation[A] <> FBestPopulation);
end;

procedure TNewDifferentialEvolution.FindDifferentPopulations(
  const Current: Integer; out A, B: Integer);
begin
  FindDifferentPopulations(Current, A);

  repeat
    B := Random(FPopulationCount);
  until (B <> Current) and (FCurrentPopulation[B] <> FBestPopulation) and (B <> A);
end;

procedure TNewDifferentialEvolution.FindDifferentPopulations(
  const Current: Integer; out A, B, C: Integer);
begin
  FindDifferentPopulations(Current, A, B);

  repeat
    C := Random(FPopulationCount);
  until (C <> Current) and (FCurrentPopulation[C] <> FBestPopulation) and (C <> B) and
    (C <> A);
end;

procedure TNewDifferentialEvolution.FindDifferentPopulations(
  const Current: Integer; out A, B, C, D: Integer);
begin
  FindDifferentPopulations(Current, A, B, C);

  repeat
    D := Random(FPopulationCount);
  until (C <> Current) and (FCurrentPopulation[D] <> FBestPopulation) and (D <> C) and
    (D <> B) and (D <> A);
end;

procedure TNewDifferentialEvolution.BuildNextGeneration;
var
  A, B, C        : Integer;
  Populations    : array [0..2] of TDEPopulationData;
  PopIndex       : Integer;
  JitterValue    : Double;
  VarIndex       : Cardinal;
  VarCount       : Cardinal;
  BasePopulation : TDEPopulationData;
  NewPopulation  : TDEPopulationData;
begin
  Assert(Assigned(FBestPopulation));

  if FUpdateInternalGains = ugPerGeneration then
    UpdateInternalGains;

  JitterValue := 0;

  for PopIndex := 0 to FPopulationCount - 1 do
  begin
    // Find 3 different populations randomly
    FindDifferentPopulations(PopIndex, A, B, C);

    BasePopulation := TDEPopulationData(FCurrentPopulation[PopIndex]);
    Populations[0] := TDEPopulationData(FCurrentPopulation[A]);
    Populations[1] := TDEPopulationData(FCurrentPopulation[B]);
    Populations[2] := TDEPopulationData(FCurrentPopulation[C]);
    NewPopulation := TDEPopulationData(FNextPopulation[PopIndex]);

    // generate trial vector with crossing-over
    VarIndex := Random(FVariableCount);
    VarCount := 0;

    if FUpdateInternalGains = ugAlways then
      UpdateInternalGains;

    // build mutation
    repeat
      if FUseJitter then
        JitterValue := CalculateJitter(VarIndex);

      NewPopulation.FData[VarIndex] := BasePopulation.FData[VarIndex] +
        Populations[0].FData[VarIndex] * FGains[0] +
        Populations[1].FData[VarIndex] * FGains[1] +
        Populations[2].FData[VarIndex] * FGains[2] +
        FBestPopulation.FData[VarIndex] * FGainBest + JitterValue;
      Inc(VarIndex);
      if VarIndex >= FVariableCount then
        VarIndex := 0;
      Inc(VarCount);
    until (VarCount >= FVariableCount) or (Random >= FCrossOver);

    // copy original population
    while (VarCount < FVariableCount) do
    begin
      NewPopulation.FData[VarIndex] := BasePopulation.FData[VarIndex];
      Inc(VarIndex);
      if VarIndex >= FVariableCount then
        VarIndex := 0;
      Inc(VarCount);
    end;
  end;
end;

function TNewDifferentialEvolution.FindBest(Generation: PPointerArray): TDEPopulationData;
var
  Best  : Double;
  Index : Integer;
begin
  Result := TDEPopulationData(Generation[0]);
  Best := Result.Cost;

  for Index := 1 to FPopulationCount - 1 do
    if (TDEPopulationData(Generation[Index]).Cost < Best) then
    begin
      Result := TDEPopulationData(Generation[Index]);
      Best := Result.Cost;
    end;
end;

procedure TNewDifferentialEvolution.SelectFittest;
var
  BestCosts : Double;
  BestPop   : TDEPopulationData;
  Index     : Integer;
  Cur, Next : TDEPopulationData;
begin
  BestPop := FBestPopulation;
  BestCosts := BestPop.Cost;
  for Index := 0 to FPopulationCount - 1 do
  begin
    Cur := TDEPopulationData(FCurrentPopulation[Index]);
    Next := TDEPopulationData(FNextPopulation[Index]);
    if (Next.Cost < Cur.Cost) then
    begin
      Assert(Next.Count = Cur.Count);
      Assert(Next.FDE = Cur.FDE);
      Move(Next.FData^, Cur.FData^, Cur.Count * SizeOf(Double));
      Cur.FCost := Next.FCost;
      if Cur.FCost < BestCosts then
      begin
        BestPop := Cur;
        BestCosts := Cur.FCost;
      end;
    end;
  end;

  BestPopulation := BestPop;
end;

procedure TNewDifferentialEvolution.CalculateCurrentGeneration;
begin
  if not IsInitialized then
    InitializeData;

  BuildNextGeneration;
  FCalcGenerationCosts(FNextPopulation);
  SelectFittest;
end;

function TNewDifferentialEvolution.CalculateJitter(
  VariableIndex: Integer): Double;
begin
  with FVariables[VariableIndex] do
    Result := Random * FJitter * (FMaximum - FMinimum);
end;

procedure TNewDifferentialEvolution.GenerationChanged;
begin
  if Assigned(FOnGenerationChanged) then
    FOnGenerationChanged(Self, FCurrentGenerationIndex);
end;

function TNewDifferentialEvolution.GetIsRunning: Boolean;
begin
  Result := Assigned(FDriverThread);
end;

function TNewDifferentialEvolution.GetNumberOfThreads: Cardinal;
begin
  Result := Length(FThreads);
end;

function TNewDifferentialEvolution.GetCurrentPopulation(
  Index: Cardinal): TDEPopulationData;
begin
  if Assigned(FCurrentPopulation) and (Index < PopulationCount) then
    Result := TDEPopulationData(FCurrentPopulation[Index])
  else
    Result := nil;
end;

procedure TNewDifferentialEvolution.JitterChanged;
begin
  FUseJitter := True;
  if FUseJitter then
    UpdateJitterGains;
end;

procedure TNewDifferentialEvolution.UpdateInternalGains;
begin
  FGainBest :=  FBestWeight;
  FGains[0] :=  FDifferentialWeight + FDither * Random *
    (1.0 - FDifferentialWeight);
  FGains[1] := -FGains[0];
  FGains[2] := -FGainBest;
end;


procedure TNewDifferentialEvolution.UpdateJitterGains;
var
  VarIndex : Integer;
begin
  ReallocMem(FJitterGains, FVariables.Count * SizeOf(Double));
  for VarIndex := 0 to FVariables.Count - 1 do
    with FVariables[VarIndex] do
      FJitterGains[VarIndex] := FJitter * (FMaximum - FMinimum);
end;

procedure TNewDifferentialEvolution.CrossoverChanged;
begin
  // nothing here yet
end;

procedure TNewDifferentialEvolution.DifferentialWeightChanged;
begin
  FGains[0] :=  FDifferentialWeight;
  FGains[1] := -FDifferentialWeight;
end;

procedure TNewDifferentialEvolution.DirectSelectionChanged;
begin
  // nothing here yet
end;

procedure TNewDifferentialEvolution.CheckUpdateInternalGains;
begin
  if (FDither > 0) then
    if FDitherPerGeneration then
      FUpdateInternalGains := ugPerGeneration
    else
      FUpdateInternalGains := ugAlways
  else
    FUpdateInternalGains := ugNone;
end;

procedure TNewDifferentialEvolution.DitherChanged;
begin
  CheckUpdateInternalGains;
end;

procedure TNewDifferentialEvolution.DitherPerGenerationChanged;
begin
  CheckUpdateInternalGains;
end;

procedure TNewDifferentialEvolution.NumberOfThreadsChanged;
begin
  if NumberOfThreads > 0 then
  begin
    if not Assigned(FCostCalculationEvent) then
      FCostCalculationEvent := TEvent.Create;
    if not Assigned(FCriticalSection) then
      FCriticalSection := TCriticalSection.Create;
    FCalcGenerationCosts := CalculateCostsThreaded;
  end
  else
  begin
    FCalcGenerationCosts := CalculateCostsDirect;
    if Assigned(FCostCalculationEvent) then
      FreeAndNil(FCostCalculationEvent);
    if Assigned(FCriticalSection) then
      FreeAndNil(FCriticalSection)
  end;
end;

procedure TNewDifferentialEvolution.PopulationCountChanged;
begin
  // nothing here yet
end;

procedure TNewDifferentialEvolution.BestPopulationChanged;
var
  BestCost : Double;
begin
  if Assigned(FOnBestCostChanged) then
  begin
    BestCost := FBestPopulation.Cost;
    FOnBestCostChanged(Self, BestCost);
  end;
end;

procedure TNewDifferentialEvolution.BestWeightChanged;
begin
  FGainBest := FBestWeight;
  FGains[2] := -FBestWeight;
end;

procedure TNewDifferentialEvolution.VariableChanged(Index: Integer);
begin
  // nothing here yet
end;

procedure TNewDifferentialEvolution.VariableCountChanged;
begin
  FVariableCount := FVariables.Count;
end;

procedure TNewDifferentialEvolution.SetBestPopulation(
  const Value: TDEPopulationData);
begin
  if FBestPopulation <> Value then
  begin
    FBestPopulation := Value;
    if Assigned(FDriverThread) then
      TThread.Synchronize(FDriverThread, BestPopulationChanged)
    else
      BestPopulationChanged;
  end;
end;

procedure TNewDifferentialEvolution.SetBestWeight(const Value: Double);
begin
  // check if new differential weight is within its bounds [0..2]
  if (Value < 0) or (Value > 2) then
    raise EDifferentialEvolution.Create(RCStrBestWeightBoundError);

  if FBestWeight <> Value then
  begin
    FBestWeight := Value;
    BestWeightChanged;
  end;
end;

procedure TNewDifferentialEvolution.SetCrossOver(const Value: Double);
begin
  // check if new crossover value is within its bounds [0..1]
  if (Value < 0) or (Value > 1) then
    raise EDifferentialEvolution.Create(RCStrCrossOverBoundError);

  if FCrossOver <> Value then
  begin
    FCrossOver := Value;
    CrossoverChanged;
  end;
end;

procedure TNewDifferentialEvolution.SetDifferentialWeight(const Value: Double);
begin
  // check if new differential weight is within its bounds [0..2]
  if (Value < 0) or (Value > 2) then
    raise EDifferentialEvolution.Create(RCStrDiffWeightBoundError);

  if FDifferentialWeight <> Value then
  begin
    FDifferentialWeight := Value;
    DifferentialWeightChanged;
  end;
end;

procedure TNewDifferentialEvolution.SetDirectSelection(const Value: Boolean);
begin
  if FDirectSelection <> Value then
  begin
    FDirectSelection := Value;
    DirectSelectionChanged;
  end;
end;

procedure TNewDifferentialEvolution.SetDither(const Value: Double);
begin
  if FDither <> Value then
  begin
    FDither := Value;
    DitherChanged;
  end;
end;

procedure TNewDifferentialEvolution.SetDitherPerGeneration(
  const Value: Boolean);
begin
  if FDitherPerGeneration <> Value then
  begin
    FDitherPerGeneration := Value;
    DitherPerGenerationChanged;
  end;
end;

procedure TNewDifferentialEvolution.SetJitter(const Value: Double);
begin
  if FJitter <> Value then
  begin
    FJitter := Value;
    JitterChanged;
  end;
end;

procedure TNewDifferentialEvolution.SetNumberOfThreads(const Value: Cardinal);
begin
  if Value <> NumberOfThreads then
  begin
    SetLength(FThreads, Value);
    NumberOfThreadsChanged;
  end;
end;

procedure TNewDifferentialEvolution.SetPopulationCount(const Value: Cardinal);
begin
  // check that at least 4 populations are specified
  if (Value < 4) then
    raise EDifferentialEvolution.Create(RCStrPopulationCountError);

  if FPopulationCount <> Value then
  begin
    FPopulationCount := Value;
    PopulationCountChanged;
  end;
end;

procedure TNewDifferentialEvolution.SetVariables(const Value
  : TDEVariableCollection);
begin
  FVariables.Assign(Value);
  FVariableCount := FVariables.Count;
end;

procedure Register;
begin
  RegisterComponents('Object Pascal Differential Evolution',
    [TNewDifferentialEvolution]);
end;

end.
