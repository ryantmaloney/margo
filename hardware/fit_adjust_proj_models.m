function [fx, fy] = fit_adjust_proj_models(x, y, proj_x, proj_y)

% fit preliminary models
fx = fit([x y],proj_x,'poly22');


% identify model outliers
z = proj_x;

% fit new fx model excluding outliers
for i=1:50
    z_hat = fx(x,y);
    err = abs(z-z_hat);
    include = err < std(err)*.2;
    fx = fit([x(include) y(include)],z(include),'poly22');
%     figure(1); plot(y(include), x(include)); hold on; plot(proj_y(include), proj_x(include), 'r'); hold off;
%     figure(2); scatter(y(include), proj_y(include)); hold on; scatter(x(include), proj_x(include), 'r'); hold off; xlabel('cam'); ylabel('proj');
%     pause(.01)
end

fy = fit([x(include) y(include)],proj_y(include),'poly22');
% identify model outliers
z = proj_y;
for i=1:50
    z_hat = fy(x,y);
    err = abs(z-z_hat);
    include = err < std(err)*.2;
   
%     figure(3); scatter(y(include), x(include)); hold on; scatter(proj_y(include), proj_x(include), 'r'); hold off;
%     figure(4); scatter(y(include), proj_y(include)); hold on; scatter(x(include), proj_x(include), 'r'); hold off; xlabel('cam'); ylabel('proj');
     fy = fit([x(include) y(include)],z(include),'poly22');
%     pause(.01)
end
