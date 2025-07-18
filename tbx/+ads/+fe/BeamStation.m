classdef BeamStation
    %BEAMSTATION Summary of this class goes here
    %   Detailed explanation goes here
    
    properties
        Point ads.fe.Point
        A = 1;
        I = eye(3);
        J = 1;
        Mat ads.fe.Material = ads.fe.Material.Aluminium;
        eta = NaN;
        % EDW  - Added properties to carry around stress recovery points. As you would expect, these are the [1,2]
        % coordinates of the C, D E and F recovery points as per the NASTRAN PBEAM docs. The arc length information comes
        % from the rest of the station definition.
        C (2,1) double = [nan;nan];
        D (2,1) double = [nan;nan];
        E (2,1) double = [nan;nan];
        F (2,1) double = [nan;nan];
    end
    methods
        function obj = BeamStation(Point,opts)
            arguments
                Point ads.fe.Point
                opts.Mat = ads.fe.Material.Aluminium;
                opts.A = 1;
                opts.I = eye(3);
                opts.J = 1;
                opts.Izz = 1;
                % EDW - also added recovery points to constructor method
                opts.C = [nan;nan];
                opts.D = [nan;nan];
                opts.E = [nan;nan];
                opts.F = [nan;nan];
            end
            obj.Point = Point;
            obj.A = opts.A;
            obj.Mat = opts.Mat;
            obj.I = opts.I;
            obj.J = opts.J;
            obj.C = opts.C;
            obj.D = opts.D;
            obj.E = opts.E;
            obj.F = opts.F;  
        end
        function matSec = ToMatranSection(obj,startPoint,endPoint)
            eta = dot(endPoint-startPoint,obj.Point.X-startPoint)/norm(endPoint-startPoint).^2;
            eta = round(eta,10); % sometimes numerical rounding errors make a 1 not a one...
            % EDW - also pass the recovery point coordinates. These are NaN by default in the matran BeamSection class, so it
            % doesn't matter if the user didn't specify them (since they're NaN by default in this class too).
            matSec = mni.printing.cards.BeamSection(obj.A, obj.I(3,3), obj.I(2,2), 0, obj.J, eta, C=obj.C, D=obj.D, E=obj.E, F=obj.F);
        end
    end
    methods(Static)
        function obj = Bar(Point,height,width,opts)
            arguments
                Point
                height
                width
                opts.Mat = ads.fe.Material.Aluminium;
            end
            Iyy=height^3*width/12;
            Izz=width^3*height/12;
            I = diag([Iyy+Izz,Iyy,Izz]);
            if height>=width
                a = height;
                b = width;
            else
                a = width;
                b = height;
            end
            J = a*b^3*(1/3-0.2085*(b/a)*(1-(b^4)/(12*a^4)));
            obj = ads.fe.BeamStation(Point,I=I,A=height*width, J=J, Mat=opts.Mat);
        end
        function obj = FromBaffStation(st,p,Mat, opts)
            arguments
                st baff.station.Beam
                p ads.fe.Point
                Mat ads.fe.Material
                % EDW - also added recovery points to the de facto constructor method
                opts.C = [nan;nan];
                opts.D = [nan;nan];
                opts.E = [nan;nan];
                opts.F = [nan;nan];
            end
            obj = ads.fe.BeamStation(p,"A",st.A,"I",st.I,"J",st.J,"Mat",Mat, ...
                                                "C", opts.C, "D", opts.D, "E", opts.E, "F", opts.F);

            %%% Added by Ed %%%
            obj.eta = st.Eta;
            %%%%%%% END %%%%%%%

        end
    end
end

