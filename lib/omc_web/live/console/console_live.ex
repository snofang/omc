defmodule OmcWeb.Console.ConsoleLive do
  use OmcWeb, :live_view

  def render(assigns) do
    ~H"""
    <div>
      <p>toto:~</p>
    </div>
    <!-- <div class="flex flex-shrink-0" role="region"> -->
    <!--   <div class="flex flex-col w-64 border-r border-gray-200 pt-5 bg-gray-100"> -->
    <!--     <.link -->
    <!--       navigate="#" -->
    <!--       class="focus:outline-none focus:ring-2 focus:ring-primary-500 focus:border-primary-500 text-gray-700 hover:text-gray-900 group flex items-center px-2 py-2 text-sm font-medium rounded-md" -->
    <!--     > -->
    <!--       Users -->
    <!--     </.link> -->
    <!--   </div> -->
    <!-- </div> -->
    """
  end
end
