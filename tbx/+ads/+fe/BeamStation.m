classdef BeamStation
    %BEAMSTATION Summary of this class goes here
    %   Detailed explanation goes here
    
    properties
        Point ads.fe.Point
        A = 1;
        I = eye(3);
        Mat ads.fe.Material = ads.fe.Material.Aluminium;
    end
    methods
        function obj = BeamStation(Point,opts)
            arguments
                Point ads.fe.Point
                opts.Mat = ads.fe.Material.Aluminium;
                opts.A = 1;
                opts.I = eye(3);
                opts.Izz = 1;
            end
            obj.Point = Point;
            obj.A = opts.A;
            obj.Mat = opts.Mat;
            obj.I = opts.I;
        end
        function matSec = ToMatranSection(obj,startPoint,endPoint)
            eta = dot(endPoint-startPoint,obj.Point.X-startPoint)/norm(endPoint-startPoint).^2;
            eta = round(eta,10); % sometimes numerical rounding errors make a 1 not a one...
            matSec = mni.printing.cards.BeamSection(obj.A,obj.I(3,3),obj.I(2,2),0,obj.I(1,1),eta);
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
            Ixx=height^3*width/12;
            Izz=width^3*height/12;
            I = diag([Ixx,Ixx+Izz,Izz]);
            obj = ads.fe.BeamStation(Point,I=I,A=height*width, Mat=opts.Mat);
        end
        function obj = FromBaffStation(st,p,Mat)
            arguments
                st baff.station.Beam
                p ads.fe.Point
                Mat ads.fe.Material
            end
            obj = ads.fe.BeamStation(p,"A",st.A,"I",st.I,"Mat",Mat);
        end
    end
end

