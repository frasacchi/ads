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
    end

end