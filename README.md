# liveview-native-swiftui-photokit

## About

`liveview-native-swiftui-photokit` is an add-on library for [LiveView Native](https://github.com/liveview-native/live_view_native). It adds [PhotoKit](https://developer.apple.com/documentation/photokit) support for uploading images from the Photos app and camera.

## Installation

1. Add this library as a package to your LiveView Native application's Xcode project
    * In Xcode, select *File* → *Add Packages...*
    * Enter the package URL `https://github.com/liveview-native/liveview-native-swiftui-photokit`
    * Select *Add Package*

## Usage

Add `.photoKit` to the `addons` list of your `#LiveView`.

```swift
import SwiftUI
import LiveViewNative
import LiveViewNativePhotoKit // 1. Import the add-on library.

struct ContentView: View {
    var body: some View {
        #LiveView(
          .localhost,
          addons: [.photoKit] // 2. Include the `PhotoKit` addon.
        )
    }
}
```

Use a `PhotosPicker` or `LiveCameraPicker` to upload images.
Include a `live_img_preview` to display the selected images before upload.

```elixir
defmodule MyAppWeb.PhotosLive.SwiftUI do
  use MyAppNative, [:render_component, format: :swiftui]

  def render(assigns) do
    ~LVN"""
    <Form>
      <LiveForm id="upload-form" phx-submit="save" phx-change="validate">
        <PhotosPicker
          data-phx-upload-ref={@uploads.avatar.ref}
          maxSelectionCount="3"
          name="avatar"
        >
          <%= @uploads.avatar.ref %>
          <Label systemImage="photo.fill">Pick Photo</Label>
        </PhotosPicker>
        <.button type="submit">Upload</.button>
      </LiveForm>
      <%!-- use phx-drop-target with the upload ref to enable file drag and drop --%>
      <Section phx-drop-target={@uploads.avatar.ref}>
        <Text template="header" :if={not Enum.empty?(@uploads.avatar.entries)}>Uploads</Text>

        <%!-- render each avatar entry --%>
        <%= for entry <- @uploads.avatar.entries do %>
          <VStack
            alignment="leading"
            style="swipeActions(content: :swipe_actions); listRowInsets(EdgeInsets(top: 8, leading: 8, bottom: 8, trailing: 8));"
          >
            <.live_img_preview entry={entry} style="resizable(); scaledToFit(); clipShape(.rect(cornerRadius: 4));" />

            <%!-- entry.progress will update automatically for in-flight entries --%>
            <ProgressView value={entry.progress} total="100">
              <%= entry.client_name %>
              <Text template="currentValueLabel"><%= entry.progress%>%</Text>
            </ProgressView>

            <%!-- Phoenix.Component.upload_errors/2 returns a list of error atoms --%>
            <%= for err <- upload_errors(@uploads.avatar, entry) do %>
              <Text style="foregroundStyle(.red); bold();"><%= error_to_string(err) %></Text>
            <% end %>

            <%!-- a regular click event whose handler will invoke Phoenix.LiveView.cancel_upload/3 --%>
            <.button
              template="swipe_actions"
              role="destructive"
              phx-click="cancel-upload"
              phx-value-ref={entry.ref}
            >
              <Image systemName="trash" />
            </.button>
          </VStack>
        <% end %>

        <%!-- Phoenix.Component.upload_errors/1 returns a list of error atoms --%>
        <%= for err <- upload_errors(@uploads.avatar) do %>
          <Text style="foregroundStyle(.red); bold();"><%= error_to_string(err) %></Text>
        <% end %>

      </Section>
    </Form>
    """
  end
end
```

https://github.com/user-attachments/assets/b0305e46-d60c-4479-8469-3c146ebf8312
