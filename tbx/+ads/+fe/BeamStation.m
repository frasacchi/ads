classdef BeamStation
    %BEAMSTATION Summary of this class goes here
    %   Detailed explanation goes here
    
    properties
        Point ads.fe.Point
        A = 1;
        I = eye(3);
        J = 1;
        Mat ads.fe.Material = ads.fe.Material.Aluminium;
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
            end
            obj.Point = Point;
            obj.A = opts.A;
            obj.Mat = opts.Mat;
            obj.I = opts.I;
            obj.J = opts.J;
        end
        function matSec = ToMatranSection(obj,startPoint,endPoint)
            eta = dot(endPoint-startPoint,obj.Point.X-startPoint)/norm(endPoint-startPoint).^2;
            eta = round(eta,10); % sometimes numerical rounding errors make a 1 not a one...
            matSec = mni.printing.cards.BeamSection(obj.A,obj.I(3,3),obj.I(2,2),0,obj.J,eta);
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
        function obj = FromBaffStation(st,p,Mat)
            arguments
                st baff.station.Beam
                p ads.fe.Point
                Mat ads.fe.Material
            end
            obj = ads.fe.BeamStation(p,"A",st.A,"I",st.I,"J",st.J,"Mat",Mat);
        end
    end
end

