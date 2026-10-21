import cv2, numpy as np
def register(base, img, mask_base=None):
    """SIFT + RANSAC 相似变换，把 img 对齐到 base。返回 (warped, M, inliers)"""
    g1=cv2.cvtColor(base,cv2.COLOR_BGR2GRAY); g2=cv2.cvtColor(img,cv2.COLOR_BGR2GRAY)
    sift=cv2.SIFT_create(4000)
    k1,d1=sift.detectAndCompute(g1,mask_base); k2,d2=sift.detectAndCompute(g2,None)
    m=cv2.BFMatcher().knnMatch(d2,d1,k=2)
    good=[a for a,b in m if a.distance<0.72*b.distance]
    src=np.float32([k2[a.queryIdx].pt for a in good]); dst=np.float32([k1[a.trainIdx].pt for a in good])
    M,inl=cv2.estimateAffinePartial2D(src,dst,method=cv2.RANSAC,ransacReprojThreshold=3,maxIters=5000)
    w=cv2.warpAffine(img,M,(base.shape[1],base.shape[0]),flags=cv2.INTER_CUBIC,borderMode=cv2.BORDER_REPLICATE)
    return w,M,int(inl.sum()),len(good)
if __name__=='__main__':
    import sys
    b=cv2.imread(sys.argv[1]); i=cv2.imread(sys.argv[2])
    w,M,n,g=register(b,i); print(M.round(4).tolist(),n,g, 'scale',np.hypot(M[0,0],M[0,1]))
    d=np.abs(w.astype(int)-b.astype(int)).sum(2).clip(0,255).astype(np.uint8)
    cv2.imwrite('/tmp/diff.png',d); cv2.imwrite('/tmp/warp.png',w)
    cv2.imwrite('/tmp/blend.png',cv2.addWeighted(b,0.5,w,0.5,0))
