classdef baff2feTest < matlab.unittest.TestCase
    properties(TestParameter)
        FoldAngles = {0,45,90};
        FlareAngles = {0,45,90};
    end
    methods(TestClassSetup)
        % Shared setup for the entire test class
    end

    methods(TestMethodSetup)
        % Setup for each test
    end

    methods(Test)
        % Test methods

        function hingeTest(testCase,FoldAngles,FlareAngles)
            %create baff hinge
            hv = fh.rotz(FlareAngles)*[1;0;0];
            hinge = baff.Hinge("HingeVector",hv);
            hinge.Rotation = FoldAngles;
            %convert to fe
            feHinge = ads.baff.element2fe(hinge);
            %check coord systems
            A_test = fh.rotz(FlareAngles)*fh.rotx(FoldAngles)*fh.rotz(-FlareAngles);
            testCase.verifyEqual(feHinge.CoordSys(1).A,A_test,'AbsTol',1e-6);
            testCase.verifyEqual(feHinge.CoordSys(2).A,fh.rotz(FlareAngles),'AbsTol',1e-6);
        end
        function connectionTest(testCase)
            % create a fuselage
            fus = baff.BluffBody.Cylinder(10,2,"NStations",11,"Material",baff.Material.Aluminium);
            fus.A = fh.rotz(90);
            %create a wing
            wing = baff.Wing.UniformWing(10,0.05,0.1,baff.Material.Aluminium,1,0.4,"NStations",11);
            wing.Offset = [-5 0 1];
            wing.A = fh.rotz(-90);
            wing.Eta = 0.5;
            fus.add(wing);
            %create model
            model = baff.Model();
            model.AddElement(fus);
            %convert to FEM
            baffOpts = ads.baff.BaffOpts();
            baffOpts.SplitBeamsAtChildren = false;
            fe = ads.baff.baff2fe(model);
%             f = figure(1);
%             clf;
%             fe.draw(f);
%             axis equal
%             xlabel('X')
            testCase.assertEqual(fe.RigidBars(1).Point1.GlobalPos,[-5;0;0]);
            testCase.assertEqual(fe.RigidBars(1).Point2.GlobalPos,[-5;0;1]);
        end

    end

end