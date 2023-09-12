export default InfiniteScroll = {
  loadMore(entries) {
    const target = entries[0];
    if (target.isIntersecting) {
      this.pushEvent("load_more", {});
    }
  },
  mounted() {
    this.observer = new IntersectionObserver(
      (entries) => this.loadMore(entries),
      {
        root: null, // window by default
        rootMargin: "0px",
        threshold: 1.0,
      }
    );
    this.observer.observe(this.el);
  },
  destroyed() {
    this.observer.unobserve(this.el);
  }
};
