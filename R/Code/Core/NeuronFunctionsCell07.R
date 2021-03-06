# NeuronFunctions5.R
# #################################
# This file contains general functions for handling Neurons:
# It has been shortened since version 4 by the removal of ParseSWCTree
# ReadSWCFile and reroot which have been moved to a new file SWCFunction.R
# Plot fns need to be updated to handle MB data
# - Have done this more or less I think need to verify esp File Plots
# #################################
# GSXEJ 020629

#RELEASE
#BEGINCOPYRIGHT
###############
# R Source Code to accompany the manuscript
#
# "Comprehensive Maps of Drosophila Higher Olfactory Centers: 
# Spatially Segregated Fruit and Pheromone Representation"
# Cell (2007), doi:10.1016/j.cell.2007.01.040
# by Gregory S.X.E. Jefferis*, Christopher J. Potter*
# Alexander M. Chan, Elizabeth C. Marin
# Torsten Rohlfing, Calvin R. Maurer, Jr., and Liqun Luo
#
# Copyright (C) 2007 Gregory Jefferis <gsxej2@cam.ac.uk>
# 
# See flybrain.stanford.edu for further details
# 
# This program is free software; you can redistribute it and/or modify
# it under the terms of the GNU General Public License as published by
# the Free Software Foundation; either version 2 of the License, or
# (at your option) any later version.
# 
# This program is distributed in the hope that it will be useful,
# but WITHOUT ANY WARRANTY; without even the implied warranty of
# MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the
# GNU General Public License for more details.
# 
# You should have received a copy of the GNU General Public License
# along with this program; if not, write to the Free Software
# Foundation, Inc., 675 Mass Ave, Cambridge, MA 02139, USA.
#################
#ENDMAINCOPYRIGHT

if(!require(rgl) && !require(scatterplot3d)){
	stop("Please install either rgl or scatterplot3d for 3d plotting")
}   # for plotneuron3d()

ReadMyChullOutput<-function(FileName){
    LinesToSkip<-2
    ColumnNames<-c("Idx","X","Y","Z")

    read.table(FileName, header = FALSE, sep = "", quote = "\"'", dec = ".",
     col.names=ColumnNames, as.is = FALSE, na.strings = "NA",
	skip = LinesToSkip, check.names = TRUE, fill = FALSE,
	strip.white = TRUE, blank.lines.skip = TRUE)
}


PointsInRegion<-function(x,ANeuron,region=c("root","MB","LH"),pointTypes=c("EP","BP")){
		CandPoints=NULL
		region=toupper(region); pointTypes=toupper(pointTypes)
		
		if("MB"%in%region) CandPoints=unique(unlist(ANeuron$SegList[unlist(ANeuron$MBSegNos)]))
		if("LH"%in%region) CandPoints=c(CandPoints,unique(unlist(ANeuron$SegList[unlist(ANeuron$LHSegNos)])))
		if("ROOT"%in%region) CandPoints=c(CandPoints,ANeuron$StartPoint)
		
		if(!"ALL"%in%pointTypes){
				cand2=NULL
				if("EP"%in%pointTypes) cand2=ANeuron$EndPoints
				if("BP"%in%pointTypes) cand2=c(cand2,ANeuron$BranchPoints)
				CandPoints=intersect(CandPoints,cand2)
		}
				
		x[x%in%CandPoints]
}

# Util function for making a line for RGL to draw
makerglline=function(df){
    if(is.null(dim(df))){
    ldf=length(df)
	if(ldf >2)
	    rep(df,rep(2, ldf))[-c(1, ldf*2)]
	else df
    } else {
    	nrdf=nrow(df)
	if(nrdf>2)
	    df[ rep(1: nrdf,rep(2, nrdf)) [-c(1, nrdf*2)],]
	else df
    }
}


####################
#                  #
#   plotneuron3d   #
#                  #
####################
plotneuron3d<-function(ANeuron,UseCurPalette=F,WithContours=T,WithScale=T,
    # note that rgl is default display mode if rgl library is available
    JustLH=F,ToFile=F,ScaleRotater=T,Colour=NULL,UseRGL=NULL,AxisDirections=c(1,-1,-1),
    # These only work with RGL at the moment
    WithLine=T,WithNodes=T,WithAllPoints=F,WithText=F,PlotSubTrees=T,ClearRGL=T,NeuronList=MyNeurons,...){    
	if (is.null(UseRGL)) {
		UseRGL=require(rgl)
	} else if(any(UseRGL)) {
		if(!require(rgl)) cat("Unable to load RGL library, switching to scatterplot3d\n")
	} 
	
    if(UseRGL && ClearRGL) rgl.clear() # clear RGL buffer
   	OldPalette<-palette()
   	if(!is.null(Colour)){
		# tricky thing is what to do if I just want colour to come out
		# as a number 
		if(!is.numeric(Colour)) {
		    # plot everything in this colour
		    palette(rep(Colour,5)) # nb palette expects >1 colour names
		}
    } else if(!UseCurPalette){
		# RGL background is black
		if(UseRGL) palette(c("white",rainbow(6)))
		else palette(c("black",rainbow(6)))
    }

    if (is.character(ANeuron))
		ANeuron<-NeuronList[[GetNeuronNum(ANeuron)]]

    if (is.numeric(ANeuron))
		ANeuron<-NeuronList[[ANeuron]]
    
    if (!is.list(ANeuron)){
		warning("Cannot understand passed neuron")
		return(F)
    }
    
    if(any(AxisDirections!=1))
		ANeuron$d[,c("X","Y","Z")]=t(t(ANeuron$d[,c("X","Y","Z")])*AxisDirections)
    
    
    # Check to see if we want to produce a rotater file
    if(ToFile!=F){
	# could either come in as true in which case a default name
	# is given to the file or as a string in which case a file
	# of that name is created in RotDir
	if(is.character(ToFile)){
	    OutFile<-file.path(RotDir,ToFile)
	} else {
	    OutFile<-file.path(RotDir,paste(ANeuron$CellType,sep="",".",ImageName(ANeuron$NeuronName),
		    ifelse(ScaleRotater,"_scl.rot",""),ifelse(WithContours,"_wc.rot","_woc.rot")))
	}
	
	# Try creating file
	if(!file.create(OutFile)) stop(paste("Couldn\'t create file",Outfile))
	# Write out some header information
	cat("#",basename(OutFile),"\n",file=OutFile,append=T)
	cat("# created on",date(),"\n",file=OutFile,append=T)
	cat("# Neuron",ImageName(ANeuron$NeuronName),"CellType",ANeuron$CellType,"\n",file=OutFile,append=T)
	cat("# NumPoints",length(ANeuron$d$X),"\n",file=OutFile,append=T)
	cat("# NumContours",ANeuron$c$ContInfo$NumContours,"\n",file=OutFile,append=T)
	# Set this flag so that later routines know to write to file
	ToFile<-T
	
	# For rotater, it's worth setting some useful point as the
	# zero position
    
	if (ScaleRotater){
	    if(!is.null(ANeuron$Scl)){
			ZeroPos<-unlist(ANeuron$c$GrandCent)
			names(ZeroPos)<-c("X","Y","Z")
			RotScl<-ANeuron$Scl
	    }
	    else{
			cat("Can't scale rotater output since",ANeuron$Name,"has no scale information")
			stop("Try sourcing SpatialAnalysis.s to update MyNeurons")
	    }
	}
	
	# Definitions for 16 bit rotator
	# If (Rotater=="Original") {
	DrawDot<--1;DrawMove<-0;DrawLine<-1
	RotDot<-function(colour){return(c(rgbcolour(colour),DrawDot))}
	RotMove<-function(colour){return(c(rgbcolour(colour),DrawMove))}
	RotLine<-function(colour){return(c(rgbcolour(colour),DrawLine))}

	# Original Rotater commands
	DrawDot<--1;DrawMove<-0;DrawLine<-1
	simpCol<-function(colour){
	    switch(colour,'red'=1,'green'=2,'blue'=3,'yellow'=4,'purple'=5,'cyan'=6,7)
	}
	# just revert to using colour numbers
	# My improved version of Rotater can handle up to 17
	simpCol<-function(colour){
	    # nb 0 => no dot, just move
	    if(colour>=0 && colour <=19) return (colour)
	    return (7)
	}    
	
	# NB here are the colour definitions from GJRotater5
########################################################################
#                                                                      #
#           case 1: R=255; G=0; B=0; break; //red                      #
#           case 2: R=0; G=255; B=0; break; //green                    #
#           case 3: R=0; G=0; B=255; break; //blue                     #
#           case 4: R=255; G=255; B=0; break; //yellow                 #
#           case 5: R=255; G=0; B=255; break; //purple                 #
#           case 6: R=0; G=255; B=255; break;  //cyan                  #
#           case 8: R=255; G=127; B=0; break;  //GJ: new colours!      #
#           case 9: R=255; G=0; B=127; break;  //GJ: new colours!      #
#           case 10: R=255; G=127; B=127; break;  //GJ: new colours!   #
#           case 11: R=127; G=255; B=0; break;  //GJ: new colours!     #
#           case 12: R=0; G=255; B=127; break;  //GJ: new colours!     #
#           case 13: R=127; G=255; B=127; break;  //GJ: new colours!   #
#           case 14: R=127; G=0; B=255; break;  //GJ: new colours!     #
#           case 15: R=0; G=127; B=255; break;  //GJ: new colours!     #
#           case 16: R=127; G=127; B=255; break;  //GJ: new colours!   #
#           case 17: R=127; G=255; B=255; break;  //GJ: new colours!   #
#           case 18: R=255; G=127; B=255; break;  //GJ: new colours!   #
#           case 19: R=255; G=255; B=127; break;  //GJ: new colours!   #
#           case 7:                                                    #
#           default: R=255; G=255; B=255; break; //white               #
#                                                                      #
########################################################################

	RotDot<-function(colour){return(simpCol(colour)*DrawDot)}
	RotMove<-function(colour){return(simpCol(colour)*DrawMove)}
	RotLine<-function(colour){return(simpCol(colour)*DrawLine)}

	RotWrite<-function(Points,PointCols,DrawMethod,Contours=F){
	    if(is.null(PointCols)) PointCols<-rep(Colour,length(Points))
	    if(length(PointCols)==1) PointCols<-rep(PointCols,length(Points))
	    
	    if(Contours){
		# GJ: added a routine to handle new style contours
		PointsXYZ=NULL
		for(ContSet in list(ANeuron$c,ANeuron$LH,ANeuron$MB)){
		    if(is.null(ContSet)) next  # Seems to be optional, but better safe
		    PointsXYZ<-c(PointsXYZ,ContSet)
		}
	    } else {
		PointsXYZ<-ANeuron$d
	    }
	    PointCols<<-PointCols
	    # Scale points to have origin at centre of LH
	    # and have lh height width etc as 1.
	    # should perhaps run these measurements
	    # on standard brains in order to figure out
	    # what would be appropriate ratios between these
	    # XYZ axes.
	    if(ScaleRotater){
		#PointsXYZ<-(PointsXYZ-ZeroPos)/RotScl
		PointsXYZ[,c("X","Y","Z")]<-scale(PointsXYZ[,c("X","Y","Z")],center=ZeroPos,scale=RotScl)
	    }
	    
	    write.table( 
		cbind( PointsXYZ[Points,c("X","Y","Z")],(sapply(PointCols,DrawMethod)) ),
		row.names=F,col.names=F,file=OutFile,append=T )
	}
    }
        
    Scl<-c(1,1,1)
    
    # UNFINISHED _ NEED TO PUT if(JustLH) in the plot routines
    if(!UseRGL){
	if(JustLH){
	    LHSegList<-ANeuron$SegList[ANeuron$LHSegNos]
	    LHPoints<-unique(unlist(LHSegList))	    
	    myxlims<-range(Scl[1]*c(ANeuron$d$X[LHPoints],ANeuron$c$d$X))
	    myylims<-range(Scl[2]*c(ANeuron$d$Y[LHPoints],ANeuron$c$d$Y))
	    myzlims<-range(Scl[3]*c(ANeuron$d$Z[LHPoints],ANeuron$c$d$Z)) 
	    
	} else {
	    # We want the whole of the neuron
	    if(WithContours){
		# UPDATED THIS TO CHECK FOR OLD AND NEW CONTOUR INFO
		myxlims<-range(Scl[1]*c(ANeuron$d$X,ANeuron$c$d$X,ANeuron$LH$d$X,ANeuron$MB$d$X))
		myylims<-range(Scl[2]*c(ANeuron$d$Y,ANeuron$c$d$Y,ANeuron$LH$d$Y,ANeuron$MB$d$Y))
		myzlims<-range(Scl[3]*c(ANeuron$d$Z,ANeuron$c$d$Z,ANeuron$LH$d$Z,ANeuron$MB$d$Z)) 
	    } else {
		myxlims<-range(Scl[1]*c(ANeuron$d$X))
		myylims<-range(Scl[2]*c(ANeuron$d$Y))
		myzlims<-range(Scl[3]*c(ANeuron$d$Z)) 
	    }
	}
    
	# I would have liked to use asp=1, but that parameter
	# doesn't seem to work for scatterplot3d
	if(WithScale){
	    AxisRanges<-abs(diff(cbind(myxlims,myylims,myzlims)))
	    MaxRange<-max(AxisRanges)
	    Deltas<-diff(rbind(AxisRanges,rep(MaxRange,3)))
	    myxlims<-myxlims+c(-Deltas[1]/2,+Deltas[1]/2)
	    myylims<-myylims+c(-Deltas[2]/2,+Deltas[2]/2)
	    myzlims<-myzlims+c(-Deltas[3]/2,+Deltas[3]/2)
	}
    }

    if(!ToFile || !is.numeric(Colour)){
	# Get the colours right to plot the root and EndPoints
	NodesOnly<-c(ANeuron$BranchPoints,
	    ANeuron$EndPoints[-which(ANeuron$EndPoints==ANeuron$StartPoint)],
	    ANeuron$StartPoint)
	NodeCols<-c(rep("red",length(ANeuron$BranchPoints)),
	    rep("green",length(ANeuron$EndPoints)-1),"purple" )
	
	if(!is.null(ANeuron$AxonLHEP)){
	    # Check if we've already put the LHEP into the array
	    if (any(NodesOnly==ANeuron$AxonLHEP)){
		NodeCols[which(NodesOnly==ANeuron$AxonLHEP)]<-"purple"
	    } else {
		NodesOnly<-c(NodesOnly,ANeuron$AxonLHEP)
		NodeCols<-c(NodeCols,"purple")
	    }
	}# end  if(!is.null(ANeuron$AxonLHEP)){
	
	# Add the LHAnchorPoint (i.e. main branch if it exists)
	if(!is.null(ANeuron$LHAnchorPoint)){
	    NodeCols[which(NodesOnly==ANeuron$LHAnchorPoint)]<-"blue"
	}# end  if(!is.null(ANeuron$LHAnchorPoint)){
    } else {
	# this is assuming colours come in as numbers
	NodesOnly<-c(ANeuron$BranchPoints,
	    ANeuron$EndPoints[-which(ANeuron$EndPoints==ANeuron$StartPoint)],
	    ANeuron$StartPoint)
	NodeCols<-c(rep(0,length(ANeuron$BranchPoints)),
	    rep(Colour,length(ANeuron$EndPoints)-1),0 )
	
	if(!is.null(ANeuron$AxonLHEP)){
	    # Check if we've already put the LHEP into the array
	    if (any(NodesOnly==ANeuron$AxonLHEP)){
		NodeCols[which(NodesOnly==ANeuron$AxonLHEP)]<-0
	    } else {
		NodesOnly<-c(NodesOnly,ANeuron$AxonLHEP)
		NodeCols<-c(NodeCols,0)
	    }
	}# end  if(!is.null(ANeuron$AxonLHEP)){
	
	# Add the LHAnchorPoint (i.e. main branch if it exists)
	if(!is.null(ANeuron$LHAnchorPoint)){
	    NodeCols[which(NodesOnly==ANeuron$LHAnchorPoint)]<-0
	}# end  if(!is.null(ANeuron$LHAnchorPoint)){

    }

    #Just nodes of neuron
	if(UseRGL){
		if(WithNodes){
			if(!WithLine) NodeCols=rep(Colour,length(NodeCols))
			rgl.points(Scl[1]*ANeuron$d$X[NodesOnly],
				Scl[2]*ANeuron$d$Y[NodesOnly],
				Scl[3]*ANeuron$d$Z[NodesOnly],color=NodeCols,size=3)
			if(WithText) # text labels for nodes
			rgl.texts(Scl[1]*ANeuron$d$X[NodesOnly],
				Scl[2]*ANeuron$d$Y[NodesOnly],
				Scl[3]*ANeuron$d$Z[NodesOnly],NodesOnly,color=NodeCols,adj=c(0,0.5))
			
		}
		
	} else if(!ToFile){	
		My3DPlot<-scatterplot3d(Scl[1]*ANeuron$d$X[NodesOnly],
			Scl[2]*ANeuron$d$Y[NodesOnly],
			Scl[3]*ANeuron$d$Z[NodesOnly],
			xlim=myxlims,ylim=myylims,zlim=myzlims,
			color=NodeCols,pch=20,main=paste(ANeuron$NeuronName,ANeuron$CellType))
	} else {
		RotWrite(NodesOnly,NodeCols,RotDot)
		cat("# End of Nodes\n",file=OutFile,append=T)
	}
	
	
    
    # all points (in white, for RGL)
    if(UseRGL && WithAllPoints){
	rgl.points(Scl[1]*ANeuron$d$X[-NodesOnly],
	    Scl[2]*ANeuron$d$Y[-NodesOnly],
	    Scl[3]*ANeuron$d$Z[-NodesOnly],color='white',size=2)
    }

    #Just neuron lines
	if(WithLine){
		if(is.null(ANeuron$SegTypes)) ANeuron$SegTypes=rep(1,ANeuron$NumSegs)
		if(UseRGL){
			if(PlotSubTrees && !is.null(ANeuron$nTrees) && ANeuron$nTrees>1){
				# handle plotting of subtrees in different colours
				for(i in 1:ANeuron$nTrees){
					pointIndexes=unlist(sapply(ANeuron$SubTrees[[i]],makerglline))
					rgl.lines(Scl[1]*ANeuron$d$X[pointIndexes],
						Scl[2]*ANeuron$d$Y[pointIndexes],
						Scl[3]*ANeuron$d$Z[pointIndexes],col=rainbow(ANeuron$nTrees)[i],...)
				}
			}  else {
				# just 1 tree
				pointIndexes=unlist(sapply(ANeuron$SegList,makerglline))
				if(!is.numeric(Colour) && !is.null(Colour)){
					cols=Colour
				} else {
					cols= rep(ANeuron$SegTypes,sapply(ANeuron$SegList,function(x) ifelse(length(x)>2,2*length(x)-2,length(x))))
					if(any(is.na(cols))) cols='red'
					else cols=palette()[cols]
					# note that if cols is passed as a number then rgl.lines
					# flashes up a regular graphics window for some reason
				}
				rgl.lines(Scl[1]*ANeuron$d$X[pointIndexes],
					Scl[2]*ANeuron$d$Y[pointIndexes],
					Scl[3]*ANeuron$d$Z[pointIndexes],col=cols,...)
			}

		} else {
			for (j in 1:ANeuron$NumSegs){
				ThisSegPoints<-ANeuron$SegList[[j]]
				if(UseRGL){
					rgl.lines(makerglline(ANeuron$d$X[ThisSegPoints]),
						makerglline(ANeuron$d$Y[ThisSegPoints]),
						makerglline(ANeuron$d$Z[ThisSegPoints]),col=ifelse(is.numeric(Colour),ANeuron$SegTypes[j],Colour))
				}
				else if(!ToFile){
					My3DPlot$points3d(Scl[1]*ANeuron$d$X[ThisSegPoints],
						Scl[2]*ANeuron$d$Y[ThisSegPoints],
						Scl[3]*ANeuron$d$Z[ThisSegPoints],col=ANeuron$SegTypes[j],type="l"
					)
				} else {
					RotWrite(ThisSegPoints[1],ANeuron$SegTypes[j],RotMove)
					RotWrite(ThisSegPoints[-1],ANeuron$SegTypes[j],RotLine)
				}
			}
			
		}
	} # end of if(WithLine){

    #Just Contours
    if(!UseRGL && WithContours){
	# This little extra loop turns out to be a nice way to deal
	# with the uncertainty of which type of contour information
	# will be present
		for(ContSet in list(ANeuron$c,ANeuron$LH,ANeuron$MB)){
		    if(is.null(ContSet)) next  # Seems to be optional, but better safe
		    for(j in unique(ContSet$d$ContourID)){
			ThisContourPoints<-which(ContSet$d$ContourID==j)
			# Just to join the circle
			ThisContourPoints<-c(ThisContourPoints,ThisContourPoints[1])
			if(!ToFile){
			    My3DPlot$points3d(Scl[1]*ContSet$d$X[ThisContourPoints],
				Scl[2]*ContSet$d$Y[ThisContourPoints],
				Scl[3]*ContSet$d$Z[ThisContourPoints]
				,type="l",lty="dotted")
			} else {
			    RotWrite(ThisContourPoints[1],'white',RotMove,Contours=T)
			    RotWrite(ThisContourPoints[-1],'white',RotDot,Contours=T)
			}
		    }
	    
		}# end for ContSet
    }
    palette(OldPalette)
    invisible(T)
    
}

#################
#               #
#   rgbcolour   #
#               #
#################
# function to return an RCB appropriate colour 3 vector
# if given an integer or a defined colour name string
rgbcolour<-function(colour){
    if(is.character(colour)){
	return(switch(colour, red=c(31,0,0), green=c(0,31,0),
	blue=c(0,0,31),purple=c(31,0,31),cyan=c(0,31,31),yellow=c(31,31,0),
	peach=c(31,15,15),eight=c(15,31,15),nine=c(15,15,31),
	ten=c(31,15,0),eleven=c(31,0,15),twelve=c(15,0,31),
	thirteen=c(15,31,0),fourteen=c(0,15,31),white=c(31,31,31) ))
    } else {   
	if(colour<1) return(rgbcolour('white'))
	return( 
rgbcolour(switch(colour,'red','green','blue','purple','cyan','yellow',
	    'peach','eight','nine','ten','eleven',
	    'twelve','thirteen','fourteen','white')) )
    }
}


#######################
#                     #
#   plotendpoint3d   #
#                     #
#######################
# function to plot only scaled endpoints directly
# to rotater files
# So far this only works for LH data (whether it is stored in $c or $LH)
plotendpoint3d<-function(ANeuron,UseCurPalette=F,WithContours=F,WithScale=T,
    JustLH=F,ToFile=T,ScaleRotater=T,ThisCol=1,FileAppend=F){
 
    if (is.character(ANeuron)){
	ANeuron<-MyNeurons[[GetNeuronNum(ANeuron)]]
    }
    if (is.numeric(ANeuron)){
	ANeuron<-MyNeurons[[ANeuron]]
    }
    
    if (!is.list(ANeuron)){
	warning("Cannot understand passed neuron")
	return(F)
    }
    
    # could either come in as true in which case a default name
    # is given to the file or as a string in which case a file
    # of that name is created in RotDir
	if(is.character(ToFile)){
		# check if ToFile is a full path or just a filename
		if(dirname(ToFile)=="."){	    
			OutFile<-file.path(RotDir,ToFile)
		} else {
			#check to see if the path is correct
			if (file.exists(dirname(ToFile))){
				OutFile<-ToFile
			} else {
				stop(paste("Couldn't find the directory referenced in the supplied ToFile",ToFile))
			}
		}
	} else {
		OutFile<-file.path(RotDir,paste(ANeuron$CellType,sep="",".",ImageName(ANeuron$NeuronName),
				".end",ifelse(ScaleRotater,".scl",""),ifelse(WithContours,".wc",".woc")))
	}
	
	
    # Try creating file if there isn't already one open
    if(!FileAppend){
	if(!file.create(OutFile)) stop(paste("Couldn\'t create file",Outfile))
    }
    
    # Write out some header information
    cat("#",basename(OutFile),"\n",file=OutFile,append=T)
    cat("# created on",date(),"\n",file=OutFile,append=T)
    cat("# Neuron",ImageName(ANeuron$NeuronName),"CellType",ANeuron$CellType,"\n",file=OutFile,append=T)
    cat("# NumPoints",length(ANeuron$d$X),"\n",file=OutFile,append=T)
    cat("# NumContours",ANeuron$c$ContInfo$NumContours,"\n",file=OutFile,append=T)
    # Set this flag so that later routines know to write to file
    ToFile<-T
    
    # For rotater, it's worth setting some useful point as the
    # zero position

    if (ScaleRotater){
	if(!is.null(ANeuron$Scl)){
	    ZeroPos<-unlist(ANeuron$c$GrandCent)
	    names(ZeroPos)<-c("X","Y","Z")
	    RotScl<-ANeuron$Scl
	}
	else{
	    cat("Can't scale rotater output since",ANeuron$Name,"has no scale information")
	    stop("Try sourcing SpatialAnalysis.s to update MyNeurons")
	}
    }
    
    # Definitions for 16 bit rotator
    DrawDot<--1;DrawMove<-0;DrawLine<-1
    RotDot<-function(colour){return(c(rgbcolour(colour),DrawDot))}
    RotMove<-function(colour){return(c(rgbcolour(colour),DrawMove))}
    RotLine<-function(colour){return(c(rgbcolour(colour),DrawLine))}

    RotWrite<-function(Points,PointCols,DrawMethod,Contours=F){

	if(length(PointCols)==1) PointCols<-rep(PointCols,length(Points))
	if(Contours){
	    PointsXYZ<-ANeuron$c$d
	} else {
	    PointsXYZ<-ANeuron$d
	}
	# Scale points to have origin at centre of LH
	# and have lh height width etc as 1.
	# should perhaps run these measurements
	# on standard brains in order to figure out
	# what would be appropriate ratios between these
	# XYZ axes.
	if(ScaleRotater){
	    #PointsXYZ<-(PointsXYZ-ZeroPos)/RotScl
	    PointsXYZ[,c("X","Y","Z")]<-scale(PointsXYZ[,c("X","Y","Z")],center=ZeroPos,scale=RotScl)
	}
	
	write.table(
	    cbind(PointsXYZ[Points,c("X","Y","Z")],
		t(sapply(PointCols,DrawMethod)) ),
	    row.names=F,col.names=F,file=OutFile,append=T)
    }
	
    # Get the colours right to plot the root and EndPoints
    LHPoints<-unique(unlist(ANeuron$SegList[ANeuron$LHSegNos]))
    LHEndPoints<-ANeuron$EndPoints[sapply(ANeuron$EndPoints,function(x){any(LHPoints==x)})]

    NodesOnly<-LHEndPoints
    NodeCols<-rep(ThisCol,length(NodesOnly))
    
    RotWrite(NodesOnly,NodeCols,RotDot)
    cat("# End of Nodes\n",file=OutFile,append=T)
     
     #Just Contours
    if(WithContours){
	# This little extra loop turns out to be a nice way to deal
	# with the uncertainty of which type of contour information
	# will be present
	for(ContSet in list(ANeuron$c,ANeuron$LH)){
	    if(is.null(ContSet)) next  # Seems to be optional, but better safe
	    for(j in unique(ContSet$d$ContourID)){
		ThisContourPoints<-which(ContSet$d$ContourID==j)
		# Just to join the circle
		ThisContourPoints<-c(ThisContourPoints,ThisContourPoints[1])
		if(!ToFile){
		    My3DPlot$points3d(Scl[1]*ContSet$d$X[ThisContourPoints],
			Scl[2]*ContSet$d$Y[ThisContourPoints],
			Scl[3]*ContSet$d$Z[ThisContourPoints]
			,type="l",lty="dotted")
		} else {
		    RotWrite(ThisContourPoints[1],'white',RotMove,Contours=T)
		    RotWrite(ThisContourPoints[-1],'white',RotDot,Contours=T)
		}
	    }

	}# end for ContSet
    }
    
    return(OutFile)
    
}




# Wrapper function to call plotneuron3d
# if given a set of neurons (names or numbers)
plotneurons3d<-function(NeuronRef,Ask=F,ToFile=F,Colours=NULL,UseRGL=TRUE,NeuronList=MyNeurons,...){
    # If there are several neurons to plot, it makes sense to pause
    if(!ToFile && !any(UseRGL)) oldpar<-par(ask=Ask)
    
    # the ... should allow any additional arguments to be passed to plotneuron2d
    if(!is.null(Colours)){
	if(length(Colours)!=length(NeuronRef)) Colours=rep(Colours[1],length(NeuronRef))
	for(i in 1:length(Colours)) plotneuron3d(NeuronRef[i],ToFile=ToFile,Colour=Colours[i],UseRGL=UseRGL,NeuronList=NeuronList,...)
    } else {
	t<-sapply(NeuronRef,plotneuron3d,ToFile=ToFile,UseRGL=UseRGL,NeuronList=NeuronList,...)
    }
    if(!ToFile && !any(UseRGL)) par(oldpar)
}

# Wrapper function to call plotendpoint3d
# if given a set of neurons (names or numbers)
plotendpoints3d<-function(NeuronRef,Ask=T,ToFile=T,Col=1,FileAppend=T,...){
    # If there are several neurons to plot, it makes sense to pause
    # the ... should allow any additional arguments to be passed to plotneuron2d
    if(length(Col)==1){
	Col<-rep(Col,length(NeuronRef))
    }
    
    if(FileAppend==T && length(NeuronRef)>1){
	FirstOutfile<-plotendpoint3d(NeuronRef[1],ToFile=ToFile,FileAppend=T,ThisCol=Col[1],...)
	if(file.exists(FirstOutfile)){
	    # all well
	    NeuronRef<-NeuronRef[-1]
	    ToFile<-FirstOutfile
	    Col<-Col[-1]
	} else {
	    stop(paste("Error writing file",FirstOutfile))
	}
	for(i in 1:length(NeuronRef)){
	    t<-
	    plotendpoint3d(NeuronRef[i],ToFile=ToFile,FileAppend=FileAppend,ThisCol=Col[i],...)
	}
	
    }
}

# Handy little function to return the MyNeurons
# subscript for a given name - see pmatch for details
# of partial matching
GetNeuronNum<-function(Nnames,mask=1:length(MyNeurons)){
    CellNames<-NULL
    for(i in mask){
	CellNames[i]<-MyNeurons[[i]]$NeuronName
    }
    Nnum<-pmatch(toupper(Nnames),toupper(CellNames),nomatch=0)
    return(Nnum)
}
GetNeuronName<-function(Nnum,mask=1:length(MyNeurons)){
    CellNames<-NULL
    for(i in mask){
	CellNames[i]<-MyNeurons[[i]]$NeuronName
    }
    Nnames<-CellNames[Nnum]
    return(Nnames)
}


# Handy little function to return the MyNeurons
# entry for a given name or number
# nb can only return one neuron
GetNeuron<-function(NeuronRef,mask=1:length(MyNeurons)){    
    if (is.character(NeuronRef)){
	Nnum<-GetNeuronNum(NeuronRef,mask)
    } else {
	# it was already a number
	Nnum<-NeuronRef
    }
    return(MyNeurons[[mask[Nnum]]])
}

# Find all the elements of x which have a match in y
matchingyinx <- function(x, y) which(match(x,y,nomatch=0)!=0)

GetNeuronNumsofType<-function(CellTypesToMatch,mask=1:length(MyNeurons)){
    CellTypesToMatch=as.character(CellTypesToMatch)
    CellTypes=sapply(MyNeurons[mask],function(x) x$CellType)
    matchingyinx(toupper(CellTypes),toupper(CellTypesToMatch))
}

GetCellType<-function(NeuronRef,mask=1:length(MyNeurons)){
    if (is.list(NeuronRef)){
	return(NeuronRef$CellType)
    } else {
        # assume that NeuronRef was a number or char
	if (is.character(NeuronRef)){
	    Nnum<-GetNeuronNum(NeuronRef,mask)
	} else {
	    # it was already a number
	    Nnum<-NeuronRef
	}
    }
    
    CellTypes<-NULL
    for(i in mask){
	CellTypes[i]<-MyNeurons[[i]]$CellType
    }
    return(CellTypes[Nnum])
}

ImageName<-function(NeuronName){
	return(unlist(strsplit(NeuronName,"[._]"))[1])
}

FirstnNeurons<-function(n=1){
    # return an array containing the index numbers of the first n neurons
    # of each class
    CellType<-NULL
    for(i in 1:length(MyNeurons)){
	CellType[i]<-MyNeurons[[i]]$CellType
    }
    
    t<-table(CellType)
    if(n>min(t)) stop("That\'s more than the least numerous cell type")
    as.vector(sapply(sort(unique(CellType)),function(x){which(CellType==x)[1:n]}))
}

NeuronNameFromFileName<-function(FileName){
	if(length(FileName)>1) return(sapply(FileName,NeuronNameFromFileName))
    # Get the name of the neuron NB strsplit returns a list)
    MyNeuronName<-unlist(strsplit(basename(FileName),"[._]"))[1]
    # Check that a sensible name resulted
    if(length(MyNeuronName)==0) stop(paste("Invalid neuron name generated from file",FileName))
    return(MyNeuronName)
}

# Guesses the likely input path of a neuron
# based on its input file name and Cell Type and the current setting
# of TraceFileDir (from Startup.R)
InputFilePath<-function(ANeuron){
    if (is.character(ANeuron)){
	ANeuron<-MyNeurons[[GetNeuronNum(ANeuron)]]
    }
    if (is.numeric(ANeuron)){
	ANeuron<-MyNeurons[[ANeuron]]
    }
    
    if (!is.list(ANeuron)){
	warning("Cannot understand passed neuron")
	return(F)
    }
    ThePath<-file.path(TraceFileDir,ANeuron$CellType,paste("traced",ANeuron$CellType))
    PathandName<-file.path(ThePath,ANeuron$InputFileName)
    return(PathandName)
}

plotall3=function(ANeuron,...){
    oldpar=par('mfrow')
    par(mfrow=c(1,3))
    plotneuron2d(ANeuron,PlotAxes='XY',...)
    plotneuron2d(ANeuron,PlotAxes='XZ',MainTitle="From above; anterior up, medial left")
    plotneuron2d(ANeuron,PlotAxes='YZ',MainTitle="From the side; anterior up, ventral left")
    par(mfrow=oldpar)
}

plot15=function(recs,...){
    if(length(recs)>15) recs=recs[1:15]
    par(mfrow=c(3,5))
    plotneurons2d(recs,...)
    par(mfrow=c(1,1))
}
plot15g=function(CellType,...){
    plot15(GetNeuronNumsofType(CellType),...)
}


# directly returns filtered vector
# doesn't fall over when pattern doesn't match anything
# 2005-02-03
mygrep=function(pattern,x,keep=TRUE,...){
    found=grep(pattern,x,...)
    if(any(found)){
	if(keep){
	    x[found]
	} else {
	    x[-found]
	}
    } else return(x)
}

getID=function(fileNames){
    if(is.factor(fileNames)) fileNames=as.character(fileNames)
    # first trim either side of first & 2nd underscores
    x=gsub("^[^_]*_([^_]*)_[^_]*.?*$","\\1",fileNames)
    # May still have something left if only 1 underscore
    x=basename(x)
    x=gsub("^([^_]*)[._].*$","\\1",x)
    x=toupper(gsub("^([A-Z]{2,3}[1-9]{1}[0-9]{0,2}[RLTB]([1-4]|LH)).*$","\\1",x,ignore.case=TRUE))
    # if the filename wasn't in a recognised format, it will likely
    # still end in 01, 02 or perhaps 03. If this is the case, remove
    # that terminal digit pair
    gsub("^(.*)0[1-3]$","\\1",x)
}
getBrain=function(fileNames){
    # trim off image number
    x=getID(fileNames)
    x=gsub("^([A-Z]{2,3}[1-9]{1}[0-9]{0,2}[RLTB])([1-4]|LH){0,1}.*$","\\1",x,ignore.case=TRUE)
    # some of Chris' ones will just end in LH
    x=gsub("^(.*)LH$","\\1",x)
	# some will still not conform to this but have a hyphenated terminus
	# eg NP6099MARCMHS35-RESIZED
	gsub("^(.?*)\\-.*$","\\1",x)

}
