function model = CantileverFFWT(FoldAngle,FlareAngle)

BarThickness = 4e-3;
BarWidth = 25e-3;
WingChord = 0.12;
BarChordwisePos = 0.25;
L = 1;
eta_hinge = 0.8;
eta_beam = 0.76;
% Make Aero Bar
mainBeam = baff.Wing.UniformWing(L*eta_beam,BarThickness,BarWidth...
    ,baff.Material.Stainless400,WingChord,BarChordwisePos,...
    "etaAeroMax",eta_hinge/eta_beam,"NAeroStations",10);
mainBeam.Name = 'Wing 1';

% Add Control Surface
% mainBeam.ControlSurfaces(1) =  baff.ControlSurface("Ail",[0.7 0.9],[0.25 0.25]);
% mainBeam.ControlSurfaces(2) =  baff.ControlSurface("Flap",[0.15 0.4],[0.35 0.35]);

% Add Masses
xs = [-21,-21,-21,-21,-21,-17]*1e-3 + (BarChordwisePos-0.25)*WingChord;
ys = [100,240,380,520,660,767]*1e-3;
mass = [ones(1,5)*0.075,0.056];
inertias = [ones(1,5)*82,26;ones(1,5)*73,32;ones(1,5)*151,56]*1e-6;
% load('Wing2ndMass.mat')
for i = 1:length(xs)
    tmp_mass = baff.Mass(mass(i));
    tmp_mass.Eta = ys(i)/(L*eta_hinge);
    tmp_mass.Offset(2) = xs(i);
    tmp_mass.Name = sprintf('tmp_mass_%.0f',i);
    tmp_mass.InertiaTensor = diag(inertias(:,i)');
    tmp_mass.mass= mass(i);
    mainBeam.add(tmp_mass);
end
% create hinge
hinge = baff.Hinge();
hinge.HingeVector = -dcrg.rotzd(FlareAngle)*[0;1;0];
hinge.Rotation = -FoldAngle;
hinge.isLocked = 0;
hinge.Eta = 1;
hinge.Offset = [L*(eta_hinge-eta_beam) (BarChordwisePos-0.5)*WingChord 0];
hinge.Name = 'SAH';
mainBeam.add(hinge);

% add wingtip
wingtip = baff.Wing.UniformWing(0.2,4e-3,30e-3,baff.Material.Stiff,WingChord,0.5,NStations=4);
wingtip.Eta = 1;
wingtip.Name = 'Wingtip';
hinge.add(wingtip);

% Add Control Surface
% wingtip.ControlSurfaces(1) =  baff.ControlSurface("Tab",[0.5 0.95],[0.3 0.3]);

%add wingtip mass
tmp_mass = baff.Mass(0.167);
tmp_mass.Offset = [0.087,-WingChord/4-0.022,0];
tmp_mass.Name = 'wingtip_mass';
tmp_mass.InertiaTensor = diag([122,942,1057])*1e-6;
wingtip.add(tmp_mass);

% Add Constraint
con = baff.Constraint("ComponentNums",123456,"eta",0,"Name","Root Connection");
con.add(mainBeam);
mainBeam.A = dcrg.rotzd(90);

% make the model
model = baff.Model;
model.AddElement(con);
model.UpdateIdx();
end
