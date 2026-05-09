classdef GBeamStation
    %   G-BEAMSTATION Summary of this class goes here
    %   Detailed explanation goes here
    
    properties
        Point ads.fe.Point
        A = 1;
        I = eye(3);
        J = 1;
        K45 = 0;
        Mat ads.fe.Material = ads.fe.Material.Aluminium;
        eta = NaN;  % Add this so we can easily keep track of where an ads element was in a BAFF wing.
        % Added properties to carry around stress recovery points. As you would expect, these are the [1,2]
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
                opts.K45 = 0;
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
            obj.K45 = opts.K45;
            obj.C = opts.C;
            obj.D = opts.D;
            obj.E = opts.E;
            obj.F = opts.F;  
        end
        % LEGACY CODE - TODO: remove if not needed

        function K_global = ToMatranStiffness(obj,startPoint,endPoint)
        %     eta = dot(endPoint-startPoint,obj.Point.X-startPoint)/norm(endPoint-startPoint).^2;
        %     eta = round(eta,10); % sometimes numerical rounding errors make a 1 not a one...
        elemL = norm(endPoint.X - startPoint.X);
        if elemL < 1e-6; error('Length is zero'); end

        %need some way to find the orientation vector of the beam!
        
        x_loc = beam_vec / L;
        z_loc = cross(x_loc, v_orientation);
        z_loc = z_loc / norm(z_loc);
        y_loc = cross(z_loc, x_loc);
        y_loc = y_loc / norm(y_loc);

        k45 = obj.K45 / elemL;
        
        % Local Coupling Terms (Twist vs Flap Slope)
        % Node 1
        K_local(4, 5) = K_local(4, 5) + k45; K_local(5, 4) = K_local(5, 4) + k45;
        % Node 2
        K_local(10, 11) = K_local(10, 11) + k45; K_local(11, 10) = K_local(11, 10) + k45;
        % Interaction
        K_local(4, 11) = K_local(4, 11) - k45; K_local(11, 4) = K_local(11, 4) - k45;
        K_local(10, 5) = K_local(10, 5) - k45; K_local(5, 10) = K_local(5, 10) - k45;

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
                % added recovery points as an option here in case we ever want to specify them in BAFF...
                opts.C = [nan;nan];
                opts.D = [nan;nan];
                opts.E = [nan;nan];
                opts.F = [nan;nan];
            end
            obj = ads.fe.BeamStation(p,"A",st.A,"I",st.I,"J",st.J,"Mat",Mat, ...
                                                "C", opts.C, "D", opts.D, "E", opts.E, "F", opts.F);
            obj.eta = st.Eta;

        end
    end
end

