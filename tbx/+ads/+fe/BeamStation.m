classdef BeamStation
    %BEAMSTATION Summary of this class goes here
    %   Detailed explanation goes here
    
    properties
        Point ads.fe.Point
        A = 1;
        Ixx = 0;
        Izz = 0;
        Mat ads.fe.Material = ads.fe.Material.Aluminium;
    end
    methods
        function obj = BeamStation(Point,opts)
            arguments
                Point ads.fe.Point
                opts.Mat = ads.fe.Material.Aluminium;
                opts.A = 1;
                opts.Ixx = 1;
                opts.Izz = 1;
            end
            obj.Point = Point;
            obj.A = opts.A;
            obj.Ixx = opts.Ixx;
            obj.Izz = opts.Izz;
            obj.Mat = opts.Mat;
        end
        function matSec = ToMatranSection(obj,startPoint,endPoint)
            eta = dot(endPoint-startPoint,obj.Point.X-startPoint)/norm(endPoint-startPoint).^2;
            matSec = mni.printing.cards.BeamSection(obj.A,obj.Izz,obj.Ixx,0,obj.Izz+obj.Ixx,eta);
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
        obj = ads.fe.BeamStation(Point,Ixx=height^3*width/12,Izz=width^3*height/12,...
            A=height*width, Mat = opts.Mat);
        end
        function obj = FromBaffStation(st,p,Mat)
            arguments
                st baff.station.Beam
                p ads.fe.Point
                Mat ads.fe.Material
            end
            obj = ads.fe.BeamStation(p,"A",st.A,"Ixx",st.Ixx,"Izz",st.Izz,"Mat",Mat);
        end
    end
end

