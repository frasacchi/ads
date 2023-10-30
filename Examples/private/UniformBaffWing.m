function model = UniformBaffWing()
BarThickness = 4e-3;
BarWidth = 40e-3;
WingChord = 0.12;
BarChordwisePos = 0.5;
L = 0.8;

% Make Aero Bar
mainBeam = baff.Wing.UniformWing(L,BarThickness,BarWidth...
    ,baff.Material.Stainless400,WingChord,BarChordwisePos,"NAeroStations",10);
mainBeam.Name = 'Wing 1';
twists = linspace(0,10,10);
for i = 1:10
    mainBeam.AeroStations(i).Twist = twists(i);
end

% Add Control Surface
% mainBeam.ControlSurfaces(1) =  baff.ControlSurface("Ail",[0.7 0.9],[0.25 0.25]);


% Add Some poiont masses to the wing
xs = [-21,-21,-21,-21,-21,-17]*1e-3 + (BarChordwisePos-0.25)*WingChord;
ys = [100,240,380,520,660,767]*1e-3;
mass = [ones(1,5)*0.075,0.056];
inertias = [ones(1,5)*82,26;ones(1,5)*73,32;ones(1,5)*151,56]*1e-6;
for i = 1:length(xs)
    tmp_mass = baff.Mass(mass(i));
    tmp_mass.Eta = ys(i)/(L);
    tmp_mass.Offset(2) = xs(i);
    tmp_mass.Name = sprintf('tmp_mass_%.0f',i);
    tmp_mass.InertiaTensor = diag(inertias(:,i)');
    tmp_mass.mass= mass(i);
    mainBeam.add(tmp_mass);
end

% add a tip mass to get a flutter mechanism
tip_mass = baff.Mass(0.05);
tip_mass.Eta = 1;
tip_mass.Offset(2) = 0.05;
tip_mass.Name = 'tip_mass';
tip_mass.InertiaTensor(1) = 2e-3;
mainBeam.add(tip_mass);


% Add Root Constraint
con = baff.Constraint("ComponentNums",123456,"eta",0,"Name","Root Connection");
con.add(mainBeam);
mainBeam.A = ads.util.rotz(90);

% make the model
model = baff.Model;
model.AddElement(con);
model.UpdateIdx();
end
