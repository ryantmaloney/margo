function cm=cmsat()
%gray colormap where undersaturated pixels are blue, and oversaturated pixels are red
cm=gray;
cm(1, 3)=1;
cm(end, 2:3)=0;
end
